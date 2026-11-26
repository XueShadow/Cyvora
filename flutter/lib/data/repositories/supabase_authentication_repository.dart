import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/authentication_error_message.dart';
import '../../features/authentication/models/authentication_repository.dart';
import '../datasources/supabase_auth_data_source.dart';

class SupabaseAuthenticationRepository implements AuthenticationRepository {
  const SupabaseAuthenticationRepository(this._dataSource);

  final SupabaseAuthDataSource _dataSource;

  @override
  Stream<AuthenticationState> watchAuthState() async* {
    try {
      await for (final state in _dataSource.authStateChanges) {
        yield _mapAuthState(state);
      }
    } on Object catch (error) {
      logAuthenticationFailure(
        error,
        operation: AuthenticationOperation.session,
      );
      throw authenticationErrorFrom(
        error,
        operation: AuthenticationOperation.session,
      );
    }
  }

  @override
  AuthenticationState get currentAuthState =>
      _mapAuthState(_dataSource.currentAuthState);

  AuthenticationState _mapAuthState(AuthState state) {
    final session = state.session;
    return AuthenticationState(
      event: switch (state.event) {
        AuthChangeEvent.initialSession => AuthenticationEvent.initialSession,
        AuthChangeEvent.passwordRecovery =>
          AuthenticationEvent.passwordRecovery,
        _ => AuthenticationEvent.other,
      },
      user: session == null
          ? null
          : AuthenticatedUser(
              id: session.user.id,
              email: session.user.email,
              userMetadata: session.user.userMetadata ?? const {},
              appMetadata: session.user.appMetadata,
            ),
    );
  }

  @override
  Future<MfaSessionState> loadMfaSessionState({
    required bool isPrivilegedAdmin,
  }) => _run(
    AuthenticationOperation.session,
    () => _dataSource.loadMfaSessionState(
      isPrivilegedAdmin: isPrivilegedAdmin,
    ),
  );

  @override
  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  }) => _run(
    AuthenticationOperation.mfaChallenge,
    () => _dataSource.requestMfaCode(
      factorId: factorId,
      isPhone: isPhone,
    ),
  );

  @override
  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) => _run(
    AuthenticationOperation.mfaVerification,
    () => _dataSource.verifyMfaCode(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    ),
  );

  @override
  Future<void> signOut() =>
      _run(AuthenticationOperation.signOut, _dataSource.signOut);

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String termsVersion,
    required String privacyPolicyVersion,
  }) => _run(
    AuthenticationOperation.signUp,
    () => _dataSource.signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      termsVersion: termsVersion,
      privacyPolicyVersion: privacyPolicyVersion,
    ),
  );

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run(
        AuthenticationOperation.signIn,
        () => _dataSource.signIn(email: email, password: password),
      );

  @override
  Future<void> resendConfirmationEmail(String email) => _run(
    AuthenticationOperation.confirmationEmail,
    () => _dataSource.resendConfirmationEmail(email),
  );

  @override
  Future<void> requestPasswordReset(String email) => _run(
    AuthenticationOperation.passwordReset,
    () => _dataSource.requestPasswordReset(email),
  );

  @override
  Future<void> updatePassword(String password) => _run(
    AuthenticationOperation.updatePassword,
    () => _dataSource.updatePassword(password),
  );

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
