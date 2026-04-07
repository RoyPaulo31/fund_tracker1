import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final List<FileObject> _files = [];

  bool _loading = false;
  String _status = 'Ready for receipts and fund documents.';

  @override
  void initState() {
    super.initState();
    _storageService = StorageService(
      _client,
      bucketName: widget.storageBucketName,
    );
    _loadFiles();
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
                      mimeType:
                          file.metadata?['mimetype']?.toString() ?? 'unknown',
                      onPreview: () => _previewFile(file),
                      onDownload: () => _downloadFile(file),
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
    required this.mimeType,
    required this.onPreview,
    required this.onDownload,
  });

  final FileObject file;
  final bool loading;
  final String mimeType;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

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
          ],
        ),
      ),
    );
  }
}
