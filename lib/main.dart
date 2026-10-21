import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Base URL: --dart-define=API_URL=https://sandbox.badrgo.com
  final prefs = await SharedPreferences.getInstance();
  configureDependencies(sharedPreferences: prefs);
  runApp(const OpsConsoleApp());
}

/// Back-compat entry used by older widget tests.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const OpsConsoleApp();
}
