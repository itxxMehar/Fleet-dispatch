import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'presentation/auth/auth_gate.dart';
import 'presentation/session/session_bloc.dart';
import 'presentation/shell/nav_catalog.dart';

class OpsConsoleApp extends StatelessWidget {
  const OpsConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = sl<SessionBloc>();
        bloc.add(const RestoreSessionRequested());
        return bloc;
      },
      child: MaterialApp(
        title: 'badrgo Ops Console',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0E6B7A),
            brightness: Brightness.light,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFFF7FAFB),
          ),
        ),
        initialRoute: AppPaths.home,
        onGenerateRoute: (settings) {
          final path = NavCatalog.normalizePath(settings.name);
          return MaterialPageRoute<void>(
            settings: RouteSettings(name: path),
            builder: (_) => AuthGate(requestedPath: path),
          );
        },
      ),
    );
  }
}
