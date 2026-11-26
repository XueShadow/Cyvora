import '../../../core/errors/authentication_error_message.dart';
import '../models/authentication_repository.dart';

class AuthActionResult {
  const AuthActionResult.success({this.confirmationEmail})
    : errorMessage = null;

  const AuthActionResult.failure(this.errorMessage) : confirmationEmail = null;

  final String? confirmationEmail;
  final String? errorMessage;

  bool get succeeded => errorMessage == null;
}

class AuthPresenter {
  const AuthPresenter(this._repository);

  static const _termsVersion = 'v2';
  static const _privacyPolicyVersion = 'v14';

  final AuthenticationRepository _repository;

  Stream<AuthenticationState> watchAuthState() => _repository.watchAuthState();

  AuthenticationState get currentAuthState => _repository.currentAuthState;

  Future<MfaSessionState> loadMfaSessionState({
    required bool isPrivilegedAdmin,
  }) => _run(
    AuthenticationOperation.session,
    () => _repository.loadMfaSessionState(
      isPrivilegedAdmin: isPrivilegedAdmin,
    ),
  );

  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  }) => _run(
    AuthenticationOperation.mfaChallenge,
    () => _repository.requestMfaCode(factorId: factorId, isPhone: isPhone),
  );

  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) => _run(
    AuthenticationOperation.mfaVerification,
    () => _repository.verifyMfaCode(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    ),
  );

  Future<void> signOut() =>
      _run(AuthenticationOperation.signOut, _repository.signOut);

  Future<AuthActionResult> submit({
    required bool creatingAccount,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    final operation = creatingAccount
        ? AuthenticationOperation.signUp
        : AuthenticationOperation.signIn;
    try {
      return await _run(operation, () async {
        if (creatingAccount) {
          final requiresConfirmation = await _repository.signUp(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            termsVersion: _termsVersion,
            privacyPolicyVersion: _privacyPolicyVersion,
          );
          return AuthActionResult.success(
            confirmationEmail: requiresConfirmation ? email : null,
          );
        }

        await _repository.signIn(email: email, password: password);
        return const AuthActionResult.success();
      });
    } on Object catch (error) {
      return AuthActionResult.failure(
        authenticationErrorFrom(error, operation: operation).message,
      );
    }
  }

  Future<AuthActionResult> resendConfirmationEmail(String email) async {
    try {
      await _run(
        AuthenticationOperation.confirmationEmail,
        () => _repository.resendConfirmationEmail(email),
      );
      return const AuthActionResult.success();
    } on Object catch (error) {
      return AuthActionResult.failure(
        authenticationErrorFrom(
          error,
          operation: AuthenticationOperation.confirmationEmail,
        ).message,
      );
    }
  }

  Future<AuthActionResult> requestPasswordReset(String email) async {
    try {
      await _run(
        AuthenticationOperation.passwordReset,
        () => _repository.requestPasswordReset(email),
      );
      return const AuthActionResult.success();
    } on Object catch (error) {
      return AuthActionResult.failure(
        authenticationErrorFrom(
          error,
          operation: AuthenticationOperation.passwordReset,
        ).message,
      );
    }
  }

  Future<AuthActionResult> updatePassword(String password) async {
    try {
      await _run(
        AuthenticationOperation.updatePassword,
        () => _repository.updatePassword(password),
      );
      return const AuthActionResult.success();
    } on Object catch (error) {
      return AuthActionResult.failure(
        authenticationErrorFrom(
          error,
          operation: AuthenticationOperation.updatePassword,
        ).message,
      );
    }
  }

  Future<T> _run<T>(
    AuthenticationOperation operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on Object catch (error) {
      logAuthenticationFailure(error, operation: operation);
      throw authenticationErrorFrom(error, operation: operation);
    }
  }
}
