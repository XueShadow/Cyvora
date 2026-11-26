import 'package:appwrite/appwrite.dart';

import 'authentication_error_message.dart';
import '../../features/authentication/models/authentication_repository.dart';

class AppwriteExceptionHandler {
  const AppwriteExceptionHandler._();

  static AuthenticationException handle(
    Object error,
    AuthenticationOperation operation,
  ) {
    if (error is AppwriteException) {
      final code = error.code;
      final message = error.message?.toLowerCase() ?? '';
      if (code == 401 ||
          message.contains('invalid credentials') ||
          message.contains('password')) {
        return const AuthenticationException(
          'The email or password is incorrect.',
          reason: AuthenticationErrorReason.invalidCredentials,
        );
      }
      if (code == 429) {
        return const AuthenticationException(
          'Too many attempts. Please wait and try again.',
          reason: AuthenticationErrorReason.rateLimited,
        );
      }
      if (code == 0 || message.contains('network')) {
        return const AuthenticationException(
          'The server could not be reached.',
          reason: AuthenticationErrorReason.networkUnavailable,
        );
      }
    }

    return const AuthenticationException(
      'Authentication is temporarily unavailable.',
      reason: AuthenticationErrorReason.serviceUnavailable,
    );
  }
}
