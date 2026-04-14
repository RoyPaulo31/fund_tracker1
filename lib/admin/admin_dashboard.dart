import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/my_account_screen.dart';
import '../fund/fund_item_details_screen.dart';
import '../models/fund_item.dart';
import '../services/fund_data_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/storage_service.dart';
import '../services/user_role_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.authService,
    required this.storageBucketName,
    required this.userRole,
  });

  final SupabaseAuthService authService;
  final String storageBucketName;
  final UserRole userRole;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const String _adminWorkFolder = 'admin_work';

  final SupabaseClient _client = Supabase.instance.client;
  late final StorageService _storageService;
  late final FundDataService _fundDataService;
  final List<FileObject> _files = [];
  final List<FundItem> _fundItems = [];

  bool _loading = false;
  String _status = 'Ready for receipts and fund documents.';

  @override
  void initState() {
    super.initState();
    _storageService = StorageService(
      _client,
      bucketName: widget.storageBucketName,
    );
    _fundDataService = FundDataService(_client);
    _loadFiles();
    _loadFundItems();
  }

  Future<void> _setLoading(Future<void> Function() action) async {
    setState(() {
      _loading = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadFiles() async {
    try {
      final files = await _storageService.listFolderFiles(_adminWorkFolder);
      if (!mounted) {
        return;
      }
      setState(() {
        _files
          ..clear()
          ..addAll(files);
      });
    } catch (error) {
      _setStatus('Could not load bucket files: $error');
    }
  }

  Future<void> _loadFundItems() async {
    try {
      final items = await _fundDataService.loadFundItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _fundItems
          ..clear()
          ..addAll(items);
      });
    } catch (error) {
      _setStatus('Could not load fund records: $error');
    }
  }

  Future<void> _openFundItem(FundItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FundItemDetailsScreen(item: item),
      ),
    );
  }

  Future<void> _openMyAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyAccountScreen(
          authService: widget.authService,
          userRole: widget.userRole,
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      _setStatus('No file selected.');
      return;
    }

    final selectedFile = result.files.first;
    await _setLoading(() async {
      try {
        await _storageService.uploadSelectedFileToFolder(
          folder: _adminWorkFolder,
          selectedFile: selectedFile,
        );
        _setStatus('Published ${selectedFile.name} to member updates.');
        await _loadFiles();
      } catch (error) {
        _setStatus('Upload failed: $error');
      }
    });
  }

  Future<void> _previewFile(FileObject file) async {
    await _setLoading(() async {
      try {
        final url = await _storageService.createSignedUrlForPath(
          '$_adminWorkFolder/${file.name}',
        );
        if (_storageService.isImage(file.name)) {
          if (!mounted) {
            return;
          }
          await showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(file.name),
                content: Image.network(url, fit: BoxFit.contain),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        } else {
          final opened = await launchUrl(Uri.parse(url));
          if (!opened) {
            _setStatus('Could not open preview URL.');
          }
        }
      } catch (error) {
        _setStatus('Preview failed: $error');
      }
    });
  }

  Future<void> _downloadFile(FileObject file) async {
    await _setLoading(() async {
      try {
        final url = await _storageService.createSignedUrlForPath(
          '$_adminWorkFolder/${file.name}',
        );
        final opened = await launchUrl(Uri.parse(url));
        if (!opened) {
          _setStatus('Could not open download URL.');
        }
      } catch (error) {
        _setStatus('Download failed: $error');
      }
    });
  }

  Future<void> _renamePublishedImage(FileObject file) async {
    final oldName = file.name;
    final oldNameWithoutExt = _baseNameWithoutExtension(oldName);
    final extension = _extensionWithDot(oldName);
    final controller = TextEditingController(text: oldNameWithoutExt);

    final submittedBaseName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename published image'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: extension.isEmpty
                  ? 'New file name'
                  : 'New file name ($extension)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (submittedBaseName == null) {
      return;
    }

    final trimmedBaseName = submittedBaseName.trim();
    if (trimmedBaseName.isEmpty) {
      _setStatus('Rename cancelled: file name cannot be empty.');
      return;
    }

    final newName = '$trimmedBaseName$extension';
    await _setLoading(() async {
      try {
        await _storageService.renameFileInFolder(
          folder: _adminWorkFolder,
          oldName: oldName,
          newName: newName,
        );
        _setStatus('Renamed $oldName to $newName.');
        await _loadFiles();
      } catch (error) {
        _setStatus('Rename failed: $error');
      }
    });
  }

  String _baseNameWithoutExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  String _extensionWithDot(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex);
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _client.auth.currentSession;
    final email = session?.user.email ?? session?.user.id ?? 'unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Org Fund Tracker'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _openMyAccount,
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'My Account',
          ),
          TextButton.icon(
            onPressed: _loading ? null : widget.authService.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Admin dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Signed in as $email • role: ${widget.userRole.label}'),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Admin work updates',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Share files that show what admins are currently working on. Members can view these updates in their panel.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loading ? null : _pickAndUploadFile,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Publish update file'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loadFiles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh files'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Fund Records',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap a record to view full details of income or expense entries.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loadFundItems,
                          icon: const Icon(Icons.sync),
                          label: const Text('Refresh fund records'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Available records (${_fundItems.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_fundItems.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No fund records yet.'),
                    ),
                  )
                else
                  ..._fundItems.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.category} • ${item.status} • PHP ${item.amount.toStringAsFixed(2)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openFundItem(item),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Shared admin files (${_files.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_files.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No files uploaded yet.'),
                    ),
                  )
                else
                  ..._files.map(
                    (file) => _BucketFileCard(
                      file: file,
                      loading: _loading,
                      canRename: _storageService.isImage(file.name),
                      mimeType:
                          file.metadata?['mimetype']?.toString() ?? 'unknown',
                      onPreview: () => _previewFile(file),
                      onDownload: () => _downloadFile(file),
                      onRename: () => _renamePublishedImage(file),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(_status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BucketFileCard extends StatelessWidget {
  const _BucketFileCard({
    required this.file,
    required this.loading,
    required this.canRename,
    required this.mimeType,
    required this.onPreview,
    required this.onDownload,
    required this.onRename,
  });

  final FileObject file;
  final bool loading;
  final bool canRename;
  final String mimeType;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(file.name),
        subtitle: Text(mimeType),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              onPressed: loading ? null : onPreview,
              icon: const Icon(Icons.remove_red_eye),
              tooltip: 'Preview',
            ),
            IconButton(
              onPressed: loading ? null : onDownload,
              icon: const Icon(Icons.download),
              tooltip: 'Download',
            ),
            IconButton(
              onPressed: loading || !canRename ? null : onRename,
              icon: const Icon(Icons.drive_file_rename_outline),
              tooltip: canRename ? 'Rename image' : 'Rename only for images',
            ),
          ],
        ),
      ),
    );
  }
}
