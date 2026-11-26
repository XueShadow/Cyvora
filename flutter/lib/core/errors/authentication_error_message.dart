import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/authentication/models/authentication_repository.dart';

enum AuthenticationOperation {
  signIn,
  signUp,
  passwordReset,
  confirmationEmail,
  updatePassword,
  session,
  mfaChallenge,
  mfaVerification,
  signOut,
}

AuthenticationException authenticationErrorFrom(
  Object error, {
  required AuthenticationOperation operation,
}) {
  if (error is AuthenticationException) return error;

  if (error is AuthPKCEGrantCodeExchangeError) {
    return const AuthenticationException(
      'This email link could not be securely completed. Request a new '
      'link and open it in the same browser.',
      reason: AuthenticationErrorReason.invalidCallback,
    );
  }

  final code = error is AuthException ? error.code?.toLowerCase() : null;
  final statusCode = error is AuthException
      ? int.tryParse(error.statusCode ?? '')
      : null;
  final isMfaOperation =
      operation == AuthenticationOperation.mfaChallenge ||
      operation == AuthenticationOperation.mfaVerification;
  final isEnumerationSensitive =
      operation == AuthenticationOperation.passwordReset ||
      operation == AuthenticationOperation.confirmationEmail;

  if (error is AuthRetryableFetchException || code == 'request_timeout') {
    return const AuthenticationException(
      'Authentication services could not be reached. Check your connection and try again.',
      reason: AuthenticationErrorReason.networkUnavailable,
    );
  }

  if (code == 'over_request_rate_limit' ||
      code == 'over_email_send_rate_limit' ||
      code == 'over_sms_send_rate_limit' ||
      statusCode == 429) {
    return const AuthenticationException(
      'Too many requests. Wait a few minutes before trying again.',
      reason: AuthenticationErrorReason.rateLimited,
    );
  }

  if (statusCode != null && statusCode >= 500) {
    return const AuthenticationException(
      'Authentication services are temporarily unavailable. Try again later.',
      reason: AuthenticationErrorReason.serviceUnavailable,
    );
  }

  if (operation == AuthenticationOperation.updatePassword &&
      (code == 'flow_state_not_found' ||
          code == 'flow_state_expired' ||
          code == 'otp_expired' ||
          code == 'invalid_grant' ||
          code == 'session_missing' ||
          code == 'session_expired' ||
          error is AuthSessionMissingException)) {
    return const AuthenticationException(
      'This password-reset link is expired or invalid. Request a new link and open it in the same browser.',
      reason: AuthenticationErrorReason.expiredRecoveryLink,
    );
  }

  if (isMfaOperation &&
      (code == 'mfa_challenge_expired' ||
          code == 'otp_expired' ||
          code == 'flow_state_expired')) {
    return const AuthenticationException(
      'This verification challenge has expired. Request a new code and try again.',
      reason: AuthenticationErrorReason.expiredMfaChallenge,
    );
  }

  if (isMfaOperation &&
      (code == 'mfa_verification_failed' ||
          code == 'mfa_verification_rejected')) {
    return const AuthenticationException(
      'The verification code was not accepted. Check it and try again.',
      reason: AuthenticationErrorReason.invalidMfaCode,
    );
  }

  if (code == 'session_expired' ||
      code == 'session_missing' ||
      code == 'session_not_found' ||
      code == 'invalid_jwt') {
    return const AuthenticationException(
      'Your session has expired. Sign in again.',
      reason: AuthenticationErrorReason.sessionExpired,
    );
  }

  if (code == 'email_not_confirmed' && !isEnumerationSensitive) {
    return const AuthenticationException(
      'Confirm your email address before signing in.',
      reason: AuthenticationErrorReason.emailNotConfirmed,
    );
  }

  if (operation == AuthenticationOperation.updatePassword &&
      (code == 'weak_password' || error is AuthWeakPasswordException)) {
    return const AuthenticationException(
      'Choose a stronger password that meets the password requirements.',
      reason: AuthenticationErrorReason.weakPassword,
    );
  }

  if (operation == AuthenticationOperation.signIn &&
      (code == 'invalid_credentials' ||
          code == 'invalid_grant' ||
          code == 'user_not_found' ||
          statusCode == 400 ||
          statusCode == 401)) {
    return const AuthenticationException(
      'Email or password is incorrect.',
      reason: AuthenticationErrorReason.invalidCredentials,
    );
  }

  if (isEnumerationSensitive) {
    return const AuthenticationException(
      'We could not process this request. Try again later.',
    );
  }

  if (operation == AuthenticationOperation.signUp &&
      (code == 'email_exists' || code == 'user_already_exists')) {
    return const AuthenticationException(
      'We could not create the account with those details. Try signing in or use password recovery.',
    );
  }

  return const AuthenticationException(
    'Authentication could not be completed. Try again.',
  );
}

void logAuthenticationFailure(
  Object error, {
  required AuthenticationOperation operation,
}) {
  if (kDebugMode) {
    debugPrint(
      'Authentication ${operation.name} failed (${error.runtimeType}).',
    );
  }
}
