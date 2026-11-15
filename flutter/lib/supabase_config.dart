import 'package:flutter/foundation.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://wohfevsfhzgxejcfcrek.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_y6QNCYwIim7n38-bRhpTZQ_WjOo4xBl',
);

String get authRedirectUrl {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    return origin.isEmpty ? 'http://localhost:3000' : origin;
  }

  return 'io.supabase.cyvora://login-callback/';
}
