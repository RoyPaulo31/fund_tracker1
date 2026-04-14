import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  SupabaseAuthService(this.client);

  final SupabaseClient client;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signInAsGuest() {
    return client.auth.signInAnonymously();
  }

  Future<void> signInWithMagicLink({required String email}) {
    return client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return client.auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }

  Future<void> signInWithGoogle() {
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }

  Future<void> signOut() {
    return client.auth.signOut();
  }
}
