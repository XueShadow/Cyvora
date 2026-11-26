import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cyvora_mobile/core/errors/authentication_error_message.dart';
import 'package:cyvora_mobile/features/authentication/models/authentication_repository.dart';

void main() {
  test('maps invalid credentials without exposing provider details', () {
    final error = authenticationErrorFrom(
      const AuthException(
        'secret provider response',
        statusCode: '401',
        code: 'invalid_credentials',
      ),
      operation: AuthenticationOperation.signIn,
    );

    expect(error.reason, AuthenticationErrorReason.invalidCredentials);
    expect(error.message, 'Email or password is incorrect.');
    expect(error.message, isNot(contains('secret')));
  });

  test('distinguishes unverified email and expired recovery links', () {
    final unverified = authenticationErrorFrom(
      const AuthException('provider detail', code: 'email_not_confirmed'),
      operation: AuthenticationOperation.signIn,
    );
    final expired = authenticationErrorFrom(
      const AuthException(
        'provider detail',
        statusCode: '400',
        code: 'flow_state_expired',
      ),
      operation: AuthenticationOperation.updatePassword,
    );

    expect(unverified.reason, AuthenticationErrorReason.emailNotConfirmed);
    expect(expired.reason, AuthenticationErrorReason.expiredRecoveryLink);
    expect(expired.message, isNot(contains('provider detail')));
  });

  test('maps expired sessions to a safe sign-in message', () {
    final error = authenticationErrorFrom(
      const AuthException(
        'private session detail',
        statusCode: '401',
        code: 'session_expired',
      ),
      operation: AuthenticationOperation.session,
    );

    expect(error.reason, AuthenticationErrorReason.sessionExpired);
    expect(error.message, 'Your session has expired. Sign in again.');
    expect(error.message, isNot(contains('private')));
  });

  test('maps network, rate-limit, service, and MFA failures safely', () {
    final network = authenticationErrorFrom(
      AuthRetryableFetchException(message: 'secret transport details'),
      operation: AuthenticationOperation.signIn,
    );
    final rateLimited = authenticationErrorFrom(
      const AuthException(
        'provider detail',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      ),
      operation: AuthenticationOperation.passwordReset,
    );
    final service = authenticationErrorFrom(
      const AuthException('provider detail', statusCode: '503'),
      operation: AuthenticationOperation.signIn,
    );
    final mfa = authenticationErrorFrom(
      const AuthException(
        'provider detail',
        code: 'mfa_verification_failed',
      ),
      operation: AuthenticationOperation.mfaVerification,
    );
    final expiredMfa = authenticationErrorFrom(
      const AuthException('provider detail', code: 'mfa_challenge_expired'),
      operation: AuthenticationOperation.mfaChallenge,
    );

    expect(network.reason, AuthenticationErrorReason.networkUnavailable);
    expect(rateLimited.reason, AuthenticationErrorReason.rateLimited);
    expect(service.reason, AuthenticationErrorReason.serviceUnavailable);
    expect(mfa.reason, AuthenticationErrorReason.invalidMfaCode);
    expect(expiredMfa.reason, AuthenticationErrorReason.expiredMfaChallenge);
    expect(network.message, isNot(contains('secret')));
  });

  test('reset and confirmation failures do not disclose account status', () {
    for (final operation in [
      AuthenticationOperation.passwordReset,
      AuthenticationOperation.confirmationEmail,
    ]) {
      final error = authenticationErrorFrom(
        const AuthException(
          'This response must not be shown',
          statusCode: '400',
          code: 'user_not_found',
        ),
        operation: operation,
      );

      expect(error.message, 'We could not process this request. Try again later.');
      expect(error.message, isNot(contains('not found')));
    }
  });

  test('handles PKCE callback failures without exposing provider text', () {
    final error = authenticationErrorFrom(
      const AuthPKCEGrantCodeExchangeError('sensitive callback details'),
      operation: AuthenticationOperation.session,
    );

    expect(error.reason, AuthenticationErrorReason.invalidCallback);
    expect(error.message, isNot(contains('sensitive')));
  });
}
