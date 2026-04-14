import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_auth_service.dart';
import '../services/user_role_service.dart';

class MyAccountScreen extends StatelessWidget {
  const MyAccountScreen({
    super.key,
    required this.authService,
    required this.userRole,
  });

  final SupabaseAuthService authService;
  final UserRole userRole;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final providers = (user?.identities ?? [])
        .map((e) => e.provider)
        .join(', ')
        .trim();

    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.person_outline,
                          size: 36,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(label: 'Email', value: user?.email ?? 'Not set'),
                    _InfoRow(label: 'User ID', value: user?.id ?? 'Unknown'),
                    _InfoRow(label: 'Role', value: userRole.label),
                    _InfoRow(
                      label: 'Auth provider',
                      value: providers.isEmpty
                          ? 'anonymous/password'
                          : providers,
                    ),
                    _InfoRow(
                      label: 'Anonymous account',
                      value: user?.isAnonymous == true ? 'Yes' : 'No',
                    ),
                    _InfoRow(
                      label: 'Last sign in',
                      value: user?.lastSignInAt ?? 'Unknown',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: authService.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: $value'),
    );
  }
}
