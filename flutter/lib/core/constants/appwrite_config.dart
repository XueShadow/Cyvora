import 'package:flutter/foundation.dart';

const appwriteEndpoint = String.fromEnvironment(
  'APPWRITE_ENDPOINT',
  defaultValue: 'https://sgp.cloud.appwrite.io/v1',
);

const appwriteProjectId = String.fromEnvironment(
  'APPWRITE_PROJECT_ID',
  defaultValue: '6b07c3da0034d57913c7',
);

const appwriteDatabaseId = String.fromEnvironment(
  'APPWRITE_DATABASE_ID',
  defaultValue: '',
);

String get appwriteAuthRedirectUrl {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    return origin.isEmpty ? 'http://localhost:3000' : origin;
  }

  return 'com.example.cyvoraMobile://login-callback/';
}
