import 'package:flutter/material.dart';

import '../../domain/entities/session.dart';
import '../alerts/alerts_page.dart';
import '../dashboard/dashboard_page.dart';
import '../map/map_page.dart';
import '../trips/trips_page.dart';
import 'access_denied_page.dart';
import 'home_overview_page.dart';
import 'nav_catalog.dart';
import 'not_found_page.dart';

/// Resolves the main content for a path against [me]'s permissions.
class ShellContent extends StatelessWidget {
  const ShellContent({super.key, required this.me, required this.path});

  final Me me;
  final String path;

  @override
  Widget build(BuildContext context) {
    final normalized = NavCatalog.normalizePath(path);
    final destination = NavCatalog.byPath(normalized);

    if (destination == null) {
      return NotFoundPage(path: normalized);
    }

    if (!destination.isAllowed(me)) {
      final required =
          destination.resource != null && destination.action != null
          ? '${destination.resource}:${destination.action}'
          : null;
      return AccessDeniedPage(path: normalized, requiredPermission: required);
    }

    return switch (destination.id) {
      'home' => HomeOverviewPage(me: me),
      'dashboard' => DashboardPage(me: me),
      'trips' => TripsPage(me: me),
      'map' => MapPage(me: me),
      'alerts' => AlertsPage(me: me),
      _ => NotFoundPage(path: normalized),
    };
  }
}
