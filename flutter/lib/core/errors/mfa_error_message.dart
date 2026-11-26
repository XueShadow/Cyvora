import 'authentication_error_message.dart';

String mfaErrorMessage(Object error) => authenticationErrorFrom(
  error,
  operation: AuthenticationOperation.mfaVerification,
).message;
