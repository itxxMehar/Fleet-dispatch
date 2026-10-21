import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../connectivity/connectivity_bloc.dart';
import '../session/session_bloc.dart';
import '../shell/app_shell.dart';
import '../shell/nav_catalog.dart';
import 'sign_in_page.dart';

/// Chooses bootstrap / sign-in / authenticated shell from [SessionBloc].
///
/// Authenticated UI is never shown until `/api/me` has succeeded.
/// [requestedPath] is checked against permissions inside [AppShell].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.requestedPath});

  final String? requestedPath;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) {
        if (state.isBootstrapping) {
          return const _BootstrapScreen();
        }
        if (state.isAuthenticated) {
          final connectivity = sl<ConnectivityBloc>()
            ..add(const ConnectivityStarted());
          return BlocProvider<ConnectivityBloc>.value(
            value: connectivity,
            child: AppShell(
              initialPath: NavCatalog.normalizePath(requestedPath),
            ),
          );
        }
        return const SignInPage();
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring session…'),
          ],
        ),
      ),
    );
  }
}
