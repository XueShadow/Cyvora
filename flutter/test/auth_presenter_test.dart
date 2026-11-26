import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  test('unexpected authentication errors are mapped to safe messages', () async {
    final repository = _FakeAuthenticationRepository()
      ..nextError = StateError('sensitive provider response');
    final presenter = AuthPresenter(repository);

    final result = await presenter.submit(
      creatingAccount: false,
      email: 'person@example.com',
      password: 'StrongPass123!',
    );

    expect(result.succeeded, isFalse);
    expect(result.errorMessage, 'Authentication could not be completed. Try again.');
    expect(result.errorMessage, isNot(contains('sensitive')));
  });

  test('password recovery request is generic and handles provider failures', () async {
    final successRepository = _FakeAuthenticationRepository();
    final success = await AuthPresenter(
      successRepository,
    ).requestPasswordReset('person@example.com');

    expect(success.succeeded, isTrue);
    expect(successRepository.passwordResetRequested, isTrue);

    final failingRepository = _FakeAuthenticationRepository()
      ..nextError = const AuthException(
        'The account exists and has internal state.',
        code: 'user_not_found',
      );
    final failure = await AuthPresenter(
      failingRepository,
    ).requestPasswordReset('person@example.com');

    expect(failure.succeeded, isFalse);
    expect(
      failure.errorMessage,
      'We could not process this request. Try again later.',
    );
    expect(failure.errorMessage, isNot(contains('account')));
  });

  test('password update reports success and maps expired recovery state', () async {
    final successRepository = _FakeAuthenticationRepository();
    final success = await AuthPresenter(
      successRepository,
    ).updatePassword('StrongPass123!');

    expect(success.succeeded, isTrue);
    expect(successRepository.passwordUpdated, isTrue);

    final failingRepository = _FakeAuthenticationRepository()
      ..nextError = const AuthException(
        'sensitive recovery token detail',
        code: 'flow_state_expired',
      );
    final failure = await AuthPresenter(
      failingRepository,
    ).updatePassword('StrongPass123!');

    expect(failure.succeeded, isFalse);
    expect(
      failure.errorMessage,
      contains('password-reset link is expired or invalid'),
    );
    expect(failure.errorMessage, isNot(contains('sensitive')));
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
  bool passwordResetRequested = false;
  bool passwordUpdated = false;

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
  Future<void> requestPasswordReset(String email) async {
    _throwPendingError();
    passwordResetRequested = true;
  }

  @override
  Future<void> updatePassword(String password) async {
    _throwPendingError();
    passwordUpdated = true;
  }
}
