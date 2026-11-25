import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gate.dart';
import 'auth_screen.dart';
import 'splash_screen.dart';
import 'supabase_config.dart';
import 'theme/cyvora_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Cyvora startup: Flutter binding ready.');

  final hasSupabaseUrl = supabaseUrl.isNotEmpty;
  final hasSupabaseKey = supabasePublishableKey.isNotEmpty;
  if (hasSupabaseUrl != hasSupabaseKey) {
    debugPrint('Cyvora startup failed: incomplete Supabase configuration.');
    throw StateError(
      'Provide both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, '
      'or leave both unset.',
    );
  }

  if (hasSupabaseUrl) {
    debugPrint('Cyvora startup: initializing Supabase.');
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
    } catch (error) {
      debugPrint(
        'Cyvora startup failed during Supabase initialization '
        '(${error.runtimeType}).',
      );
      rethrow;
    }
    debugPrint('Cyvora startup: Supabase initialized.');
  } else {
    debugPrint('Cyvora startup: Supabase is not configured.');
  }

  debugPrint('Cyvora startup: launching Flutter app.');
  runApp(MyApp(supabaseConfigured: hasSupabaseUrl, showSplash: true));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.supabaseConfigured,
    this.showSplash = false,
  });

  final bool supabaseConfigured;
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyvora',
      debugShowCheckedModeBanner: false,
      theme: cyvoraTheme(),
      home: showSplash
          ? SplashScreen(
              destination: supabaseConfigured
                  ? const AuthGate()
                  : const AuthScreen(supabaseConfigured: false),
            )
          : supabaseConfigured
          ? const AuthGate()
          : const AuthScreen(supabaseConfigured: false),
    );
  }
}
