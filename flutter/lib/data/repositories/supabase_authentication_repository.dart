import 'package:supabase_flutter/supabase_flutter.dart';

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
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
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
  }) async {
    try {
      return await _dataSource.loadMfaSessionState(
        isPrivilegedAdmin: isPrivilegedAdmin,
      );
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    }
  }

  @override
  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  }) async {
    try {
      return await _dataSource.requestMfaCode(
        factorId: factorId,
        isPhone: isPhone,
      );
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    }
  }

  @override
  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    try {
      await _dataSource.verifyMfaCode(
        factorId: factorId,
        challengeId: challengeId,
        code: code,
      );
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _dataSource.signOut();
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    }
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String termsVersion,
    required String privacyPolicyVersion,
  }) async {
    try {
      return await _dataSource.signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        termsVersion: termsVersion,
        privacyPolicyVersion: privacyPolicyVersion,
      );
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    } on Exception catch (error) {
      throw AuthenticationException('Could not connect to Supabase: $error');
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _dataSource.signIn(email: email, password: password);
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    } on Exception catch (error) {
      throw AuthenticationException('Could not connect to Supabase: $error');
    }
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {
    try {
      await _dataSource.resendConfirmationEmail(email);
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    } on Exception catch (error) {
      throw AuthenticationException(
        'Could not request a confirmation email: $error',
      );
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _dataSource.requestPasswordReset(email);
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    } on Exception catch (error) {
      throw AuthenticationException('Could not connect to Supabase: $error');
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    try {
      await _dataSource.updatePassword(password);
    } on AuthException catch (error) {
      throw AuthenticationException(error.message);
    } on Exception catch (error) {
      throw AuthenticationException('Could not update your password: $error');
    }
  }
}
