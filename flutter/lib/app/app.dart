import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/cyvora_theme.dart';
import 'app_dependencies.dart';
import 'app_routes.dart';

class CyvoraApp extends StatelessWidget {
  const CyvoraApp({
    super.key,
    required this.dependencies,
    this.showSplash = false,
  });

  final AppDependencies dependencies;
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyvora',
      debugShowCheckedModeBanner: false,
      theme: cyvoraTheme(),
      initialRoute: AppRoutes.home,
      routes: AppRoutes.create(
        dependencies: dependencies,
        showSplash: showSplash,
      ),
    );
  }
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
    return CyvoraApp(
      dependencies: supabaseConfigured
          ? AppDependencies.fromSupabase(Supabase.instance.client)
          : const AppDependencies(supabaseConfigured: false),
      showSplash: showSplash,
    );
  }
}
