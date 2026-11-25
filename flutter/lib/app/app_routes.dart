import 'package:flutter/widgets.dart';

import '../features/authentication/views/auth_gate.dart';
import '../features/authentication/views/auth_screen.dart';
import '../features/splash/views/splash_screen.dart';
import 'app_dependencies.dart';

abstract final class AppRoutes {
  static const home = '/';

  static Map<String, WidgetBuilder> create({
    required AppDependencies dependencies,
    required bool showSplash,
  }) {
    final Widget destination;
    if (dependencies.supabaseConfigured) {
      final authPresenter = dependencies.authPresenter;
      final dashboardPresenter = dependencies.dashboardPresenter;
      final permissionPresenter = dependencies.permissionPresenter;
      if (authPresenter == null ||
          dashboardPresenter == null ||
          permissionPresenter == null) {
        throw StateError(
          'Configured Supabase dependencies are missing from the app container.',
        );
      }
      destination = AuthGate(
        authPresenter: authPresenter,
        dashboardPresenter: dashboardPresenter,
        permissionPresenter: permissionPresenter,
      );
    } else {
      destination = const AuthScreen(supabaseConfigured: false);
    }
    final initialScreen = showSplash
        ? SplashScreen(destination: destination)
        : destination;
    return {home: (_) => initialScreen};
  }
}
