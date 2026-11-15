import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'dashboard/dashboard_repository.dart';
import 'dashboard/dashboard_screen.dart' as dashboard;
import 'mfa_challenge_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        auth.currentSession,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is AuthException &&
              error.message ==
                  'Code verifier could not be found in local storage.') {
            return const AuthCallbackRecoveryScreen();
          }

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Authentication error: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const _PasswordRecoveryScreen();
        }

        final session = snapshot.data?.session;
        if (session == null) return const AuthScreen();
        final metadata = session.user.userMetadata ?? const <String, dynamic>{};
        final appMetadata = session.user.appMetadata;
        final firstName = metadata['first_name'];
        final lastName = metadata['last_name'];
        final avatarPath = metadata['avatar_path'];
        final trustedRole = appMetadata['role'];
        return _MfaSessionGate(
          key: ValueKey(session.user.id),
          child: dashboard.DashboardScreen(
            email: session.user.email ?? 'Cyvora member',
            firstName: firstName is String ? firstName : '',
            lastName: lastName is String ? lastName : '',
            avatarPath: avatarPath is String ? avatarPath : null,
            userId: session.user.id,
            isTrustedModerator:
                trustedRole == 'moderator' || trustedRole == 'admin',
            isTrustedAdmin: trustedRole == 'admin',
            onSignOut: () => auth.signOut(),
            repository: SupabaseDashboardRepository(Supabase.instance.client),
          ),
        );
      },
    );
  }
}

class _MfaSessionGate extends StatefulWidget {
  const _MfaSessionGate({required this.child, super.key});

  final Widget child;

  @override
  State<_MfaSessionGate> createState() => _MfaSessionGateState();
}

class _MfaSessionGateState extends State<_MfaSessionGate> {
  bool _isLoading = true;
  bool _requiresChallenge = false;
  bool _hasSupportedPhoneFactor = false;
  List<PhoneMfaFactorOption> _factors = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMfaState();
  }

  Future<void> _loadMfaState() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      final factors = await auth.mfa.listFactors();
      final assurance = auth.mfa.getAuthenticatorAssuranceLevel();
      final requiresChallenge =
          assurance.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
          assurance.currentLevel != AuthenticatorAssuranceLevels.aal2;
      final phoneFactors = factors.all
          .where(
            (factor) =>
                factor.status == FactorStatus.verified &&
                factor.factorType == FactorType.phone,
          )
          .map(
            (factor) =>
                (id: factor.id, label: factor.friendlyName ?? 'your phone'),
          )
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _requiresChallenge = requiresChallenge;
          _factors = phoneFactors;
          _hasSupportedPhoneFactor = phoneFactors.isNotEmpty;
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _requestCode(String factorId) async {
    final challenge = await Supabase.instance.client.auth.mfa.challenge(
      factorId: factorId,
      channel: OtpChannel.sms,
    );
    return challenge.id;
  }

  Future<void> _verifyCode(
    String factorId,
    String challengeId,
    String code,
  ) async {
    await Supabase.instance.client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Account security could not be verified. Your account is '
                  'locked until the verification service is available.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('Details: $_error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadMfaState,
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: () => auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_requiresChallenge) return widget.child;
    if (!_hasSupportedPhoneFactor) {
      return MfaChallengeScreen(
        factors: const [],
        onRequestCode: _requestCode,
        onVerifyCode: _verifyCode,
        onVerified: () => setState(() => _requiresChallenge = false),
        onSignOut: () => auth.signOut(),
      );
    }
    return MfaChallengeScreen(
      factors: _factors,
      onRequestCode: _requestCode,
      onVerifyCode: _verifyCode,
      onVerified: () => setState(() => _requiresChallenge = false),
      onSignOut: () => auth.signOut(),
    );
  }
}

class AuthCallbackRecoveryScreen extends StatefulWidget {
  const AuthCallbackRecoveryScreen({super.key});

  @override
  State<AuthCallbackRecoveryScreen> createState() =>
      _AuthCallbackRecoveryScreenState();
}

class _AuthCallbackRecoveryScreenState
    extends State<AuthCallbackRecoveryScreen> {
  bool _showSignIn = false;

  @override
  Widget build(BuildContext context) {
    if (_showSignIn) return const AuthScreen();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: Color(0xFF34E89B),
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Continue to Cyvora',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFEAF4FF),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The confirmation link returned, but this browser could not '
                  'finish secure sign-in. Your email may already be confirmed. '
                  'Continue to sign in; if it is not confirmed, request a new '
                  'link and open it in the same browser where you signed up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9BB2C9), height: 1.55),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('continue-to-sign-in'),
                    onPressed: () => setState(() => _showSignIn = true),
                    child: const Text('Continue to sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRecoveryScreen extends StatefulWidget {
  const _PasswordRecoveryScreen();

  @override
  State<_PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<_PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isBusy = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isBusy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully. Please sign in again.'),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update your password: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFF34E89B),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose a new password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFEAF4FF),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.length < 12) {
                          return 'Use at least 12 characters';
                        }
                        final hasUppercase = password.contains(RegExp(r'[A-Z]'));
                        final hasLowercase = password.contains(RegExp(r'[a-z]'));
                        final hasNumber = password.contains(RegExp(r'[0-9]'));
                        final hasSymbol = password.contains(
                          RegExp(r'[^A-Za-z0-9]'),
                        );
                        final categoryCount = [
                          hasUppercase,
                          hasLowercase,
                          hasNumber,
                          hasSymbol,
                        ].where((flag) => flag).length;
                        if (categoryCount < 3) {
                          return 'Use 3 of 4 character types';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isPasswordVisible,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _isBusy ? null : _updatePassword,
                      child: _isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update password'),
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
