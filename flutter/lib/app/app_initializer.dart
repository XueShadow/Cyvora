import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_config.dart';
import 'app_dependencies.dart';

class AppInitializer {
  const AppInitializer._();

  static Future<AppDependencies> initialize() async {
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

    if (!hasSupabaseUrl) {
      return const AppDependencies(supabaseConfigured: false);
    }

    return AppDependencies.fromSupabase(Supabase.instance.client);
  }
}
