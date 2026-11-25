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
  }) => _repository.loadMfaSessionState(isPrivilegedAdmin: isPrivilegedAdmin);

  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  }) => _repository.requestMfaCode(factorId: factorId, isPhone: isPhone);

  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) => _repository.verifyMfaCode(
    factorId: factorId,
    challengeId: challengeId,
    code: code,
  );

  Future<void> signOut() => _repository.signOut();

  Future<AuthActionResult> submit({
    required bool creatingAccount,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    try {
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
    } on AuthenticationException catch (error) {
      return AuthActionResult.failure(error.message);
    }
  }

  Future<AuthActionResult> resendConfirmationEmail(String email) async {
    try {
      await _repository.resendConfirmationEmail(email);
      return const AuthActionResult.success();
    } on AuthenticationException catch (error) {
      return AuthActionResult.failure(error.message);
    }
  }

  Future<AuthActionResult> requestPasswordReset(String email) async {
    try {
      await _repository.requestPasswordReset(email);
      return const AuthActionResult.success();
    } on AuthenticationException catch (error) {
      return AuthActionResult.failure(error.message);
    }
  }

  Future<AuthActionResult> updatePassword(String password) async {
    try {
      await _repository.updatePassword(password);
      return const AuthActionResult.success();
    } on AuthenticationException catch (error) {
      return AuthActionResult.failure(error.message);
    }
  }
}
