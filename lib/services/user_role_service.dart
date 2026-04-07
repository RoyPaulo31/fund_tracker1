import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { admin, member }

extension UserRoleX on UserRole {
  static UserRole fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'admin':
        return UserRole.admin;
      case 'member':
      case 'user':
        return UserRole.member;
      default:
        return UserRole.member;
    }
  }

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.member:
        return 'member';
    }
  }

  bool get isAdmin => this == UserRole.admin;
}

class UserRoleService {
  UserRoleService(this.client);

  final SupabaseClient client;

  Future<UserRole> loadUserRole(Session session) async {
    final result = await resolveUserRole(session);
    return result.role;
  }

  Future<RoleResolutionResult> resolveUserRole(Session session) async {
    String? warning;

    try {
      final result = await client
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .limit(1)
          .maybeSingle();

      final roleValue = result?['role']?.toString();
      final role = UserRoleX.fromValue(roleValue);
      return RoleResolutionResult(
        role: role,
        source: 'profiles.id',
        rawRoleValue: roleValue,
      );
    } catch (error) {
      warning = 'profiles.id lookup failed: $error';
    }

    final email = session.user.email;
    if (email != null && email.isNotEmpty) {
      try {
        final result = await client
            .from('profiles')
            .select('role')
            .eq('email', email)
            .limit(1)
            .maybeSingle();

        final roleValue = result?['role']?.toString();
        final role = UserRoleX.fromValue(roleValue);
        return RoleResolutionResult(
          role: role,
          source: 'profiles.email',
          rawRoleValue: roleValue,
          warning:
              'Resolved by email fallback. Check profiles.id matches auth.users.id.',
        );
      } catch (error) {
        final message = 'profiles.email lookup failed: $error';
        warning = message;
      }
    }

    final String? metadataRole =
        session.user.appMetadata['role']?.toString() ??
        session.user.userMetadata?['role']?.toString();
    final metadataParsed = UserRoleX.fromValue(metadataRole);
    return RoleResolutionResult(
      role: metadataParsed,
      source: metadataRole?.isNotEmpty == true
          ? 'auth.metadata'
          : 'default.member',
      rawRoleValue: metadataRole,
      warning: warning,
    );
  }
}

class RoleResolutionResult {
  const RoleResolutionResult({
    required this.role,
    required this.source,
    required this.rawRoleValue,
    this.warning,
  });

  final UserRole role;
  final String source;
  final String? rawRoleValue;
  final String? warning;
}
