import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;

import '../../core/constants/appwrite_config.dart';
import '../../features/authentication/models/authentication_repository.dart';

class AppwriteAuthDataSource {
  AppwriteAuthDataSource(this._account);

  final Account _account;

  Stream<AuthenticationState> authStateChanges() async* {
    while (true) {
      try {
        final user = await _account.get();
        yield AuthenticationState(
          event: AuthenticationEvent.initialSession,
          user: AuthenticatedUser(
            id: user.$id,
            email: user.email,
            userMetadata: user.prefs.data,
            appMetadata: const {},
          ),
        );
      } on AppwriteException catch (error) {
        if (error.code == 401) {
          yield const AuthenticationState(
            event: AuthenticationEvent.initialSession,
          );
        } else {
          rethrow;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  Future<AuthenticationState> get currentAuthState async {
    try {
      final user = await _account.get();
      return AuthenticationState(
        event: AuthenticationEvent.initialSession,
        user: AuthenticatedUser(
          id: user.$id,
          email: user.email,
          userMetadata: user.prefs.data,
          appMetadata: const {},
        ),
      );
    } on AppwriteException catch (error) {
      if (error.code == 401) {
        return const AuthenticationState(
          event: AuthenticationEvent.initialSession,
        );
      }
      rethrow;
    }
  }

  Future<MfaSessionState> loadMfaSessionState({
    required bool isPrivilegedAdmin,
  }) async {
    final factors = await _account.listMFAFactors();
    final supported = <AuthenticationFactor>[
      if (factors.totp)
        const (id: 'totp', label: 'authenticator app', isPhone: false),
      if (factors.phone)
        const (id: 'phone', label: 'phone', isPhone: true),
      if (factors.email)
        const (id: 'email', label: 'email', isPhone: false),
    ];
    return MfaSessionState(
      requiresChallenge: isPrivilegedAdmin && supported.isEmpty,
      factors: supported,
    );
  }

  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  }) async {
    final factor = isPhone
        ? appwrite_enums.AuthenticationFactor.phone
        : appwrite_enums.AuthenticationFactor.totp;
    final challenge = await _account.createMFAChallenge(
      factor: factor,
    );
    return challenge.$id;
  }

  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    await _account.updateMFAChallenge(
      challengeId: challengeId,
      otp: code,
    );
  }

  Future<void> signOut() =>
      _account.deleteSession(sessionId: 'current');

  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String termsVersion,
    required String privacyPolicyVersion,
  }) async {
    await _account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: '$firstName $lastName',
    );
    await _account.createEmailVerification(
      url: appwriteAuthRedirectUrl,
    );
    return true;
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) =>
      _account.createEmailPasswordSession(
        email: email,
        password: password,
      );

  Future<void> resendConfirmationEmail(String email) =>
      _account.createEmailVerification(url: appwriteAuthRedirectUrl);

  Future<void> requestPasswordReset(String email) =>
      _account.createRecovery(
        email: email,
        url: appwriteAuthRedirectUrl,
      );

  Future<void> updatePassword(String password) =>
      _account.updatePassword(password: password);
}
