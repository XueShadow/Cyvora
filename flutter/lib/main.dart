import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gate.dart';
import 'auth_screen.dart';
import 'splash_screen.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final hasSupabaseUrl = supabaseUrl.isNotEmpty;
  final hasSupabaseKey = supabasePublishableKey.isNotEmpty;
  if (hasSupabaseUrl != hasSupabaseKey) {
    throw StateError(
      'Provide both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, '
      'or leave both unset.',
    );
  }

  if (hasSupabaseUrl) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }

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
    const canvas = Color(0xFF041523);
    const card = Color(0xFF09283D);
    const green = Color(0xFF34E89B);
    const text = Color(0xFFEAF4FF);
    const muted = Color(0xFF9BB2C9);

    return MaterialApp(
      title: 'Cyvora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          brightness: Brightness.dark,
          primary: green,
          onPrimary: const Color(0xFF03251E),
          surface: card,
        ),
        scaffoldBackgroundColor: canvas,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: text,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
          bodyMedium: TextStyle(color: text),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B2A3D),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: const TextStyle(color: muted),
          prefixIconColor: const Color(0xFFBDD0E1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFF285268)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFF285268)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: green, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFD64B4B)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFD64B4B), width: 1.6),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: muted),
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? green : null,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: card,
          titleTextStyle: const TextStyle(
            color: text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(color: muted, height: 1.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF16445A)),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF12384A),
          contentTextStyle: TextStyle(color: text),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: green,
          selectionColor: Color(0x5534E89B),
          selectionHandleColor: green,
        ),
      ),
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
