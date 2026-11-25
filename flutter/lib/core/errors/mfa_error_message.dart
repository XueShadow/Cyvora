import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/authentication/models/authentication_repository.dart';

String mfaErrorMessage(Object error) {
  final message = switch (error) {
    AuthException() => error.message.trim(),
    AuthenticationException() => error.message.trim(),
    _ => error.toString().trim(),
  };
  final normalized = message.toLowerCase();
  if (normalized.contains('rate') ||
      normalized.contains('too many') ||
      normalized.contains('429')) {
    return 'Too many verification requests. Wait a few minutes before trying again.';
  }
  if (normalized.contains('expired') ||
      normalized.contains('challenge') && normalized.contains('invalid')) {
    return 'This verification code expired. Request a new code and try again.';
  }
  if (normalized.contains('network') ||
      normalized.contains('timeout') ||
      normalized.contains('connection')) {
    return 'The verification service could not be reached. Check your connection and try again.';
  }
  return message.isEmpty ? 'The verification request failed.' : message;
}
