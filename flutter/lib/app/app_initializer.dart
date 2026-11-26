import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_config.dart';
import '../data/appwrite/appwrite_initializer.dart';
import 'app_dependencies.dart';

class AppInitializer {
  const AppInitializer._();

  static Future<AppDependencies> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('Cyvora startup: Flutter binding ready.');

    final appwriteClient = AppwriteInitializer.initialize();
    final appwriteProvider =
        appwriteClient == null ? null : AppwriteClientProvider(appwriteClient);

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
      if (appwriteProvider != null) {
        return AppDependencies.fromAppwrite(appwriteProvider);
      }
      return const AppDependencies(supabaseConfigured: false);
    }

    final supabaseClient = Supabase.instance.client;
    if (appwriteProvider != null) {
      return AppDependencies.fromAppwrite(
        appwriteProvider,
        supabaseClient: supabaseClient,
      );
    }
    return AppDependencies.fromSupabase(supabaseClient);
  }
}
