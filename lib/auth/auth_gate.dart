import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_dashboard.dart';
import '../services/supabase_auth_service.dart';
import '../services/user_role_service.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SupabaseClient _client = Supabase.instance.client;
  late final SupabaseAuthService _authService;
  late final UserRoleService _roleService;
  StreamSubscription<AuthState>? _subscription;

  Session? _session;
  UserRole _role = UserRole.unknown;
  bool _loadingRole = false;
  String? _errorMessage;
  String? _roleDebugMessage;

  @override
  void initState() {
    super.initState();
    _authService = SupabaseAuthService(_client);
    _roleService = UserRoleService(_client);
    _session = _client.auth.currentSession;
    _loadingRole = _session != null;
    _subscription = _client.auth.onAuthStateChange.listen((data) {
      _applySession(data.session);
    });
    if (_session != null) {
      _loadRole(_session!);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _applySession(Session? session) {
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _errorMessage = null;
      _roleDebugMessage = null;
      _role = UserRole.unknown;
      _loadingRole = session != null;
    });
    if (session != null) {
      _loadRole(session);
    }
  }

  Future<void> _loadRole(Session session) async {
    try {
      final resolution = await _roleService.resolveUserRole(session);
      if (!mounted) {
        return;
      }
      setState(() {
        _role = resolution.role;
        _loadingRole = false;
        _roleDebugMessage =
            'role_source=${resolution.source}, raw_role=${resolution.rawRoleValue ?? 'null'}, user_id=${session.user.id}${resolution.warning == null ? '' : ', note=${resolution.warning}'}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _role = UserRole.unknown;
        _loadingRole = false;
        _errorMessage = 'Could not resolve admin role: $error';
        _roleDebugMessage =
            'role_resolution_exception=$error, user_id=${session.user.id}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    if (session == null) {
      return LoginScreen(
        authService: _authService,
        errorMessage: _errorMessage,
      );
    }

    if (_loadingRole) {
      return const _LoadingScreen(message: 'Checking admin access...');
    }

    if (_role.isAdmin) {
      return AdminDashboard(
        authService: _authService,
        storageBucketName: 'receipts',
        userRole: _role,
      );
    }

    return _AccessDeniedScreen(
      authService: _authService,
      role: _role,
      email: session.user.email,
      userId: session.user.id,
      errorMessage: _errorMessage,
      debugMessage: _roleDebugMessage,
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({
    required this.authService,
    required this.role,
    required this.email,
    required this.userId,
    required this.errorMessage,
    required this.debugMessage,
  });

  final SupabaseAuthService authService;
  final UserRole role;
  final String? email;
  final String userId;
  final String? errorMessage;
  final String? debugMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Org Fund Tracker'),
        actions: [
          TextButton(
            onPressed: authService.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 72),
                const SizedBox(height: 16),
                Text(
                  'Access restricted',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Signed in as ${email ?? 'unknown user'} with role "${role.label}".',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'User ID: $userId',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This fund tracker is admin-only. Ask an org admin to set your role to admin in the profiles table or auth metadata.',
                  textAlign: TextAlign.center,
                ),
                if (debugMessage != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    debugMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: authService.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
