import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_config.dart';
import '../../features/authentication/models/authentication_repository.dart';

class SupabaseAuthDataSource {
  const SupabaseAuthDataSource(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  AuthState get currentAuthState =>
      AuthState(AuthChangeEvent.initialSession, _client.auth.currentSession);

  Future<MfaSessionState> loadMfaSessionState({
    required bool isPrivilegedAdmin,
  }) async {
    final response = await _client.auth.mfa.listFactors();
    final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    final verifiedFactors = response.all
        .where(
          (factor) =>
              factor.status == FactorStatus.verified &&
              (factor.factorType == FactorType.phone ||
                  factor.factorType == FactorType.totp),
        )
        .map(
          (factor) => (
            id: factor.id,
            label:
                factor.friendlyName ??
                (factor.factorType == FactorType.phone
                    ? 'your phone'
                    : 'authenticator app'),
            isPhone: factor.factorType == FactorType.phone,
          ),
        )
        .toList(growable: false);
    final requiresChallenge = isPrivilegedAdmin
        ? verifiedFactors.isEmpty ||
              assurance.currentLevel != AuthenticatorAssuranceLevels.aal2
        : assurance.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
              assurance.currentLevel != AuthenticatorAssuranceLevels.aal2;
    return MfaSessionState(
      requiresChallenge: requiresChallenge,
      factors: verifiedFactors,
    );
  }

  Future<String> requestMfaCode({
    required String factorId,
    required bool isPhone,
  }) async {
    final challenge = isPhone
        ? await _client.auth.mfa.challenge(
            factorId: factorId,
            channel: OtpChannel.sms,
          )
        : await _client.auth.mfa.challenge(factorId: factorId);
    return challenge.id;
  }

  Future<void> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    await _client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String termsVersion,
    required String privacyPolicyVersion,
  }) async {
    final acceptedAt = DateTime.now().toUtc().toIso8601String();
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'terms_accepted_at': acceptedAt,
        'terms_version': termsVersion,
        'privacy_policy_accepted_at': acceptedAt,
        'privacy_policy_version': privacyPolicyVersion,
      },
      emailRedirectTo: authRedirectUrl,
    );
    return response.session == null;
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> resendConfirmationEmail(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: authRedirectUrl,
    );
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: authRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }
}
