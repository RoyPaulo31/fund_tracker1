import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/my_account_screen.dart';
import '../fund/fund_item_details_screen.dart';
import '../models/fund_item.dart';
import '../services/fund_data_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/user_role_service.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({
    super.key,
    required this.authService,
    required this.storageBucketName,
    required this.userRole,
  });

  final SupabaseAuthService authService;
  final String storageBucketName;
  final UserRole userRole;

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  static const String _adminWorkFolder = 'admin_work';

  final SupabaseClient _client = Supabase.instance.client;
  late final StorageService _storageService;
  late final FundDataService _fundDataService;
  final List<FileObject> _adminWorkFiles = [];
  final List<FundItem> _fundItems = [];

  bool _loading = false;
  String _status = 'Viewing admin work updates.';

  @override
  void initState() {
    super.initState();
    _storageService = StorageService(
      _client,
      bucketName: widget.storageBucketName,
    );
    _fundDataService = FundDataService(_client);
    _loadAdminWorkFiles();
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

  Future<void> _loadAdminWorkFiles() async {
    await _setLoading(() async {
      try {
        final files = await _storageService.listFolderFiles(_adminWorkFolder);
        if (!mounted) {
          return;
        }
        setState(() {
          _adminWorkFiles
            ..clear()
            ..addAll(files);
          _status = files.isEmpty
              ? 'No admin work has been shared yet.'
              : 'Showing latest admin work activity.';
        });
      } catch (error) {
        _setStatus('Could not load admin work files: $error');
      }
    });
  }

  Future<void> _openFile(FileObject file) async {
    await _setLoading(() async {
      try {
        final url = await _storageService.createSignedUrlForPath(
          '$_adminWorkFolder/${file.name}',
        );
        final opened = await launchUrl(Uri.parse(url));
        if (!opened) {
          _setStatus('Could not open file.');
        }
      } catch (error) {
        _setStatus('Open failed: $error');
      }
    });
  }

  Future<void> _loadFundItems() async {
    await _setLoading(() async {
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
    });
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
                  'Member panel',
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
                          'What admins are working on',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Members can view files and progress documents shared by admins.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loadAdminWorkFiles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh admin updates'),
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
                          'Tap any item below to open the full record details.',
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
                  'Admin work files (${_adminWorkFiles.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_adminWorkFiles.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No shared admin updates yet.'),
                    ),
                  )
                else
                  ..._adminWorkFiles.map(
                    (file) => Card(
                      child: ListTile(
                        title: Text(file.name),
                        subtitle: Text(
                          file.metadata?['mimetype']?.toString() ?? 'unknown',
                        ),
                        trailing: IconButton(
                          onPressed: _loading ? null : () => _openFile(file),
                          icon: const Icon(Icons.open_in_new),
                          tooltip: 'Open',
                        ),
                      ),
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
