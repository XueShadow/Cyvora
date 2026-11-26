import 'package:material_ui/material_ui.dart';

import '../../../core/errors/authentication_error_message.dart';
import '../../dashboard/views/dashboard_screen.dart' as dashboard;
import '../../dashboard/presenters/dashboard_presenter.dart';
import '../../permissions/presenters/permission_presenter.dart';
import '../models/authentication_repository.dart';
import '../presenters/auth_presenter.dart';
import 'auth_screen.dart';
import 'mfa_challenge_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authPresenter,
    required this.dashboardPresenter,
    required this.permissionPresenter,
  });

  final AuthPresenter authPresenter;
  final DashboardPresenter dashboardPresenter;
  final PermissionPresenter permissionPresenter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthenticationState>(
      stream: authPresenter.watchAuthState(),
      initialData: authPresenter.currentAuthState,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is AuthenticationException &&
              error.reason == AuthenticationErrorReason.invalidCallback) {
            return AuthCallbackRecoveryScreen(presenter: authPresenter);
          }

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  authenticationErrorFrom(
                    error ?? StateError('Authentication stream failed.'),
                    operation: AuthenticationOperation.session,
                  ).message,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.data?.event == AuthenticationEvent.passwordRecovery) {
          return _PasswordRecoveryScreen(presenter: authPresenter);
        }

        final user = snapshot.data?.user;
        if (user == null) return AuthScreen(presenter: authPresenter);
        final metadata = user.userMetadata;
        final appMetadata = user.appMetadata;
        final firstName = metadata['first_name'];
        final lastName = metadata['last_name'];
        final avatarPath = metadata['avatar_path'];
        final trustedRole = appMetadata['role'];
        final isTrustedAdmin =
            trustedRole == 'super_admin' ||
            trustedRole == 'admin' ||
            trustedRole == 'moderator' ||
            trustedRole == 'support_admin';
        return _MfaSessionGate(
          key: ValueKey(user.id),
          authState: snapshot.data!,
          isPrivilegedAdmin: isTrustedAdmin,
          presenter: authPresenter,
          child: dashboard.DashboardScreen(
            email: user.email ?? 'Cyvora member',
            firstName: firstName is String ? firstName : '',
            lastName: lastName is String ? lastName : '',
            avatarPath: avatarPath is String ? avatarPath : null,
            userId: user.id,
            isTrustedModerator:
                trustedRole == 'moderator' ||
                trustedRole == 'admin' ||
                trustedRole == 'super_admin',
            isTrustedAdmin:
                trustedRole == 'admin' || trustedRole == 'super_admin',
            onSignOut: authPresenter.signOut,
            presenter: dashboardPresenter,
            permissionPresenter: permissionPresenter,
          ),
        );
      },
    );
  }
}

class _MfaSessionGate extends StatefulWidget {
  const _MfaSessionGate({
    required this.child,
    required this.authState,
    required this.isPrivilegedAdmin,
    required this.presenter,
    super.key,
  });

  final Widget child;
  final AuthenticationState authState;
  final bool isPrivilegedAdmin;
  final AuthPresenter presenter;

  @override
  State<_MfaSessionGate> createState() => _MfaSessionGateState();
}

class _MfaSessionGateState extends State<_MfaSessionGate> {
  bool _isLoading = true;
  bool _requiresChallenge = false;
  List<AuthenticationFactor> _factors = const [];
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadMfaState();
  }

  @override
  void didUpdateWidget(covariant _MfaSessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authState != widget.authState) {
      _loadMfaState();
    }
  }

  Future<void> _loadMfaState() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final mfaState = await widget.presenter.loadMfaSessionState(
        isPrivilegedAdmin: widget.isPrivilegedAdmin,
      );
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _requiresChallenge = mfaState.requiresChallenge;
          _factors = mfaState.factors;
        });
      }
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(
          () => _error = authenticationErrorFrom(
            error,
            operation: AuthenticationOperation.session,
          ).message,
        );
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _requestCode(String factorId) async {
    final factor = _factors.firstWhere((factor) => factor.id == factorId);
    return widget.presenter.requestMfaCode(
      factorId: factorId,
      isPhone: factor.isPhone,
    );
  }

  Future<void> _verifyCode(
    String factorId,
    String challengeId,
    String code,
  ) async {
    await widget.presenter.verifyMfaCode(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
  }

  Future<void> _onVerified() => _loadMfaState();

  Future<void> _signOut() async {
    try {
      await widget.presenter.signOut();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = authenticationErrorFrom(
            error,
            operation: AuthenticationOperation.signOut,
          ).message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadMfaState,
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_requiresChallenge) return widget.child;
    return MfaChallengeScreen(
      factors: _factors,
      onRequestCode: _requestCode,
      onVerifyCode: _verifyCode,
      onVerified: _onVerified,
      onSignOut: _signOut,
    );
  }
}

class AuthCallbackRecoveryScreen extends StatefulWidget {
  const AuthCallbackRecoveryScreen({super.key, this.presenter});

  final AuthPresenter? presenter;

  @override
  State<AuthCallbackRecoveryScreen> createState() =>
      _AuthCallbackRecoveryScreenState();
}

class _AuthCallbackRecoveryScreenState
    extends State<AuthCallbackRecoveryScreen> {
  bool _showSignIn = false;

  @override
  Widget build(BuildContext context) {
    if (_showSignIn) {
      return AuthScreen(presenter: widget.presenter);
    }

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
                  color: Color(0xFF8B5CF6),
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Continue to Cyvora',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This email link could not be securely completed in this '
                  'browser. Request a new confirmation or password-reset link '
                  'and open it in the same browser where you started. You can '
                  'continue to sign in or use Forgot password to restart recovery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFC4B5FD), height: 1.55),
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
  const _PasswordRecoveryScreen({required this.presenter});

  final AuthPresenter presenter;

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
    if (_isBusy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isBusy = true);
    try {
      final result = await widget.presenter.updatePassword(
        _passwordController.text,
      );
      if (!result.succeeded) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(result.errorMessage!)));
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password updated successfully.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authenticationErrorFrom(
                error,
                operation: AuthenticationOperation.updatePassword,
              ).message,
            ),
          ),
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
                      color: Color(0xFF8B5CF6),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose a new password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
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
                        final hasUppercase = password.contains(
                          RegExp(r'[A-Z]'),
                        );
                        final hasLowercase = password.contains(
                          RegExp(r'[a-z]'),
                        );
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
