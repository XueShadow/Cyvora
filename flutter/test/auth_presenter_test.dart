import 'package:flutter_test/flutter_test.dart';

import 'package:cyvora_mobile/features/authentication/models/authentication_repository.dart';
import 'package:cyvora_mobile/features/authentication/presenters/auth_presenter.dart';

void main() {
  test(
    'registration delegates consent metadata and requests confirmation',
    () async {
      final repository = _FakeAuthenticationRepository()
        ..requiresConfirmation = true;
      final presenter = AuthPresenter(repository);

      final result = await presenter.submit(
        creatingAccount: true,
        email: 'person@example.com',
        password: 'StrongPass123!',
        firstName: 'First',
        lastName: 'Last',
      );

      expect(result.succeeded, isTrue);
      expect(result.confirmationEmail, 'person@example.com');
      expect(repository.registeredName, 'First Last');
      expect(repository.termsVersion, isNotEmpty);
      expect(repository.privacyPolicyVersion, isNotEmpty);
    },
  );

  test('authentication failures are presented as explicit results', () async {
    final repository = _FakeAuthenticationRepository()
      ..nextError = const AuthenticationException('Invalid credentials.');
    final presenter = AuthPresenter(repository);

    final result = await presenter.submit(
      creatingAccount: false,
      email: 'person@example.com',
      password: 'invalid',
    );

    expect(result.succeeded, isFalse);
    expect(result.errorMessage, 'Invalid credentials.');
  });

  test('authentication validation preserves password requirements', () {
    expect(AuthenticationValidation.isValidEmail('person@example.com'), isTrue);
    expect(AuthenticationValidation.isValidEmail('person@localhost'), isFalse);
    expect(
      AuthenticationValidation.hasStrongPassword('StrongPass123!'),
      isTrue,
    );
    expect(AuthenticationValidation.hasStrongPassword('Short1!'), isFalse);
  });
}

class _FakeAuthenticationRepository implements AuthenticationRepository {
  bool requiresConfirmation = false;
  Object? nextError;
  String? registeredName;
  String? termsVersion;
  String? privacyPolicyVersion;

  void _throwPendingError() {
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
  }

  @override
  Stream<AuthenticationState> watchAuthState() =>
      const Stream<AuthenticationState>.empty();

  @override
  AuthenticationState get currentAuthState =>
      const AuthenticationState(event: AuthenticationEvent.initialSession);

  @override
  Future<MfaSessionState> loadMfaSessionState({
    required bool isPrivilegedAdmin,
  }) async => const MfaSessionState(requiresChallenge: false, factors: []);

  @override
  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  }) async => 'challenge';

  @override
  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String termsVersion,
    required String privacyPolicyVersion,
  }) async {
    _throwPendingError();
    registeredName = '$firstName $lastName';
    this.termsVersion = termsVersion;
    this.privacyPolicyVersion = privacyPolicyVersion;
    return requiresConfirmation;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _throwPendingError();
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}
}
