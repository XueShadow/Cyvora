import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/app_initializer.dart';

export 'app/app.dart' show MyApp;

Future<void> main() async {
  final dependencies = await AppInitializer.initialize();
  debugPrint('Cyvora startup: launching Flutter app.');
  runApp(CyvoraApp(dependencies: dependencies, showSplash: true));
}
