import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_dashboard.dart';
import '../member/member_dashboard.dart';
import '../services/supabase_auth_service.dart';
import '../services/user_role_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService, this.errorMessage});

  final SupabaseAuthService authService;
  final String? errorMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _showRecoveryOptions = false;
  bool _obscurePassword = true;
  String _status = 'Use your org email or Google account to sign in.';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _setStatus('Email and password are required for email sign-in.');
      return false;
    }
    if (!email.contains('@')) {
      _setStatus('Please enter a valid email address.');
      return false;
    }
    if (password.length < 6) {
      _setStatus('Password must be at least 6 characters.');
      return false;
    }

    return _formKey.currentState?.validate() ?? false;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (!_validateInputs()) {
      return;
    }

    setState(() {
      _loading = true;
      _showRecoveryOptions = false;
    });

    try {
      await action();
      _setStatus('Request completed.');
    } on AuthException catch (error) {
      _setStatus(_friendlyAuthMessage(error));
      if (error.message.toLowerCase().contains('invalid login credentials')) {
        setState(() {
          _showRecoveryOptions = true;
        });
      }
    } catch (error) {
      _setStatus('Authentication failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openSignedInPanel() async {
    final session = widget.authService.client.auth.currentSession;
    if (session == null || !mounted) {
      return;
    }

    final roleService = UserRoleService(widget.authService.client);
    final resolution = await roleService.resolveUserRole(session);
    if (!mounted) {
      return;
    }

    final nextScreen = resolution.role.isAdmin
        ? AdminDashboard(
            authService: widget.authService,
            storageBucketName: 'receipts',
            userRole: resolution.role,
          )
        : MemberDashboard(
            authService: widget.authService,
            storageBucketName: 'receipts',
            userRole: resolution.role,
          );

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => nextScreen));
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    await _runAction(() {
      return widget.authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    });

    await _openSignedInPanel();
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    await _runAction(() {
      return widget.authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    });
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setStatus('Enter your email address before requesting a login link.');
      return;
    }

    setState(() {
      _loading = true;
      _showRecoveryOptions = false;
    });

    try {
      await widget.authService.signInWithMagicLink(email: email);
      _setStatus('Login link sent. Check your email to continue.');
    } on AuthException catch (error) {
      _setStatus(_friendlyAuthMessage(error));
    } catch (error) {
      _setStatus('Could not send login link. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendPasswordSetupEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setStatus(
        'Enter your email address before requesting a password setup link.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _showRecoveryOptions = false;
    });

    try {
      await widget.authService.sendPasswordResetEmail(email: email);
      _setStatus(
        'Password setup link sent. Open the email to create a password, then sign in with email/password.',
      );
    } on AuthException catch (error) {
      _setStatus(_friendlyAuthMessage(error));
    } catch (error) {
      _setStatus('Could not send password setup link. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
    });

    try {
      await widget.authService.signInWithGoogle();
      _setStatus('Google sign-in started in a new page.');
    } on AuthException catch (error) {
      _setStatus(_friendlyAuthMessage(error));
    } catch (error) {
      _setStatus('Google sign-in could not be started.');
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

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String _friendlyAuthMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Invalid email or password. If this account was created with Google, send a password setup link first.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email first, then sign in.';
    }
    if (message.contains('user already registered')) {
      return 'This email is already registered. Use Sign in instead.';
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Student Org Fund Tracker',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Admins can publish work updates and members can view them. Google-created accounts need a password setup link before email/password sign-in will work.',
                        textAlign: TextAlign.center,
                      ),
                      if (widget.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: _requiredValidator,
                              decoration: const InputDecoration(
                                labelText: 'Org email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              validator: _requiredValidator,
                              onFieldSubmitted: (_) =>
                                  _loading ? null : _signIn(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _signIn,
                        child: const Text('Sign in with email/password'),
                      ),
                      if (_showRecoveryOptions) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _sendMagicLink,
                          icon: const Icon(Icons.mark_email_read_outlined),
                          label: const Text('Send login link to this email'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _sendPasswordSetupEmail,
                          icon: const Icon(Icons.password_outlined),
                          label: const Text('Set a password for this account'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _loading ? null : _signUp,
                        child: const Text('Create account'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google'),
                      ),
                      const SizedBox(height: 16),
                      Text(_status, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
