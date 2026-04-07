import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_dashboard.dart';
import '../member/member_dashboard.dart';
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
  UserRole _role = UserRole.member;
  bool _loadingRole = false;
  String? _errorMessage;

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
      _role = UserRole.member;
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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _role = UserRole.member;
        _loadingRole = false;
        _errorMessage = 'Could not resolve role, defaulted to member: $error';
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
      return const _LoadingScreen(message: 'Loading your panel...');
    }

    if (_role.isAdmin) {
      return AdminDashboard(
        authService: _authService,
        storageBucketName: 'receipts',
        userRole: _role,
      );
    }

    return MemberDashboard(
      authService: _authService,
      storageBucketName: 'receipts',
      userRole: _role,
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
