import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cuaduhsxecopgdqjphav.supabase.co',
    anonKey: 'sb_publishable_Gja9VahCmTvaZdQNlJ-sMg_SJrdHEgv',
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const SupabaseAuthPage(),
    );
  }
}

class SupabaseAuthPage extends StatefulWidget {
  const SupabaseAuthPage({super.key});

  @override
  State<SupabaseAuthPage> createState() => _SupabaseAuthPageState();
}

class _SupabaseAuthPageState extends State<SupabaseAuthPage> {
  static const String _bucketName = 'receipts';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _client = Supabase.instance.client;
  final List<FileObject> _bucketFiles = [];

  StreamSubscription<AuthState>? _authSubscription;
  late final Stream<AuthState> _authStateStream;
  bool _loading = false;
  String _status =
      'Connected to Supabase. Enter email/password to sign up or sign in.';

  @override
  void initState() {
    super.initState();
    _authStateStream = _client.auth.onAuthStateChange;
    _authSubscription = _authStateStream.listen((_) {
      _loadBucketFiles();
    });
    _loadBucketFiles();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    await _runAuthAction(() async {
      await _client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _setStatus(
        'Sign up request sent. Check your email if confirmation is enabled.',
      );
    });
  }

  Future<void> _signIn() async {
    await _runAuthAction(() async {
      await _client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _setStatus('Signed in successfully.');
    });
  }

  Future<void> _signOut() async {
    await _runAuthAction(() async {
      await _client.auth.signOut();
      _setStatus('Signed out.');
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
    });

    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
      _setStatus('Google sign-in started. Complete login in the opened page.');
    } on AuthException catch (error) {
      _setStatus('Google auth error: ${error.message}');
    } catch (error) {
      _setStatus('Unexpected Google sign-in error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _setStatus('Sign in first before uploading to Storage.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      _setStatus('No file selected.');
      return;
    }

    final selected = picked.files.first;
    final bytes = selected.bytes;
    if (bytes == null) {
      _setStatus('Could not read selected file bytes.');
      return;
    }

    setState(() {
      _loading = true;
    });

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = selected.name.replaceAll(' ', '_');
    final filePath = '${user.id}/${timestamp}_$fileName';
    final contentType = _contentTypeFromName(fileName);

    try {
      await _client.storage
          .from(_bucketName)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      _setStatus('Uploaded: $fileName');
      await _loadBucketFiles();
    } on StorageException catch (error) {
      _setStatus('Storage error: ${error.message}');
    } catch (error) {
      _setStatus('Unexpected upload error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadBucketFiles() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bucketFiles.clear();
      });
      return;
    }

    try {
      final files = await _client.storage.from(_bucketName).list(path: user.id);
      if (!mounted) {
        return;
      }
      files.sort((a, b) {
        final aCreated = a.createdAt ?? '';
        final bCreated = b.createdAt ?? '';
        return bCreated.compareTo(aCreated);
      });
      setState(() {
        _bucketFiles
          ..clear()
          ..addAll(files);
      });
    } on StorageException catch (error) {
      _setStatus('Storage list error: ${error.message}');
    } catch (error) {
      _setStatus('Unexpected list error: $error');
    }
  }

  Future<void> _previewFile(FileObject file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _setStatus('Sign in first to preview files.');
      return;
    }

    final path = '${user.id}/${file.name}';
    try {
      final signedUrl = await _client.storage
          .from(_bucketName)
          .createSignedUrl(path, 600);

      if (_isImage(file.name)) {
        if (!mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(file.name),
              content: Image.network(signedUrl, fit: BoxFit.contain),
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
        final opened = await launchUrl(Uri.parse(signedUrl));
        if (!opened) {
          _setStatus('Could not open preview URL.');
        }
      }
    } on StorageException catch (error) {
      _setStatus('Preview error: ${error.message}');
    } catch (error) {
      _setStatus('Unexpected preview error: $error');
    }
  }

  Future<void> _downloadFile(FileObject file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _setStatus('Sign in first to download files.');
      return;
    }

    final path = '${user.id}/${file.name}';
    try {
      final signedUrl = await _client.storage
          .from(_bucketName)
          .createSignedUrl(path, 600);
      final opened = await launchUrl(Uri.parse(signedUrl));
      if (!opened) {
        _setStatus('Could not open download URL.');
      }
    } on StorageException catch (error) {
      _setStatus('Download error: ${error.message}');
    } catch (error) {
      _setStatus('Unexpected download error: $error');
    }
  }

  bool _isImage(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String _contentTypeFromName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    return 'application/octet-stream';
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _setStatus('Email and password are required.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await action();
    } on AuthException catch (error) {
      _setStatus('Auth error: ${error.message}');
    } catch (error) {
      _setStatus('Unexpected error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      builder: (context, _) {
        final session = _client.auth.currentSession;
        return Scaffold(
          appBar: AppBar(title: const Text('Fund Tracker + Supabase')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      session == null
                          ? 'No active user session'
                          : 'Signed in as: ${session.user.email ?? session.user.id}',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _signUp,
                      child: const Text('Sign up'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _loading ? null : _signIn,
                      child: const Text('Sign in'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.login),
                      label: const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _loading ? null : _signOut,
                      child: const Text('Sign out'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _loading ? null : _pickAndUploadFile,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload image/pdf'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _loadBucketFiles,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh bucket files'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bucket files (${_bucketFiles.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._bucketFiles.map((file) {
                      return Card(
                        child: ListTile(
                          title: Text(file.name),
                          subtitle: Text(
                            file.metadata?['mimetype']?.toString() ??
                                'unknown type',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: _loading
                                    ? null
                                    : () => _previewFile(file),
                                icon: const Icon(Icons.remove_red_eye),
                                tooltip: 'Preview',
                              ),
                              IconButton(
                                onPressed: _loading
                                    ? null
                                    : () => _downloadFile(file),
                                icon: const Icon(Icons.download),
                                tooltip: 'Download',
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    Text(_status),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
