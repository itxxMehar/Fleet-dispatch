import 'package:flutter/material.dart';

import '../../domain/entities/session.dart';
import 'nav_destination.dart';

/// Canonical app paths used by the shell and web deep links.
abstract final class AppPaths {
  static const home = '/';
  static const dashboard = '/dashboard';
  static const trips = '/trips';
  static const map = '/map';
  static const alerts = '/alerts';
}

/// All module destinations. Filter with [visibleDestinations] — never by role.
abstract final class NavCatalog {
  static const destinations = <NavDestination>[
    NavDestination(
      id: 'home',
      path: AppPaths.home,
      label: 'Home',
      icon: Icons.home_outlined,
    ),
    NavDestination(
      id: 'dashboard',
      path: AppPaths.dashboard,
      label: 'Dashboard',
      icon: Icons.insights_outlined,
      resource: 'kpi',
      action: 'read',
    ),
    NavDestination(
      id: 'trips',
      path: AppPaths.trips,
      label: 'Trips',
      icon: Icons.route_outlined,
      resource: 'trip',
      action: 'read',
    ),
    NavDestination(
      id: 'map',
      path: AppPaths.map,
      label: 'Live map',
      icon: Icons.map_outlined,
      resource: 'driver',
      action: 'track',
    ),
    NavDestination(
      id: 'alerts',
      path: AppPaths.alerts,
      label: 'Alerts',
      icon: Icons.notifications_outlined,
      resource: 'alert',
      action: 'read',
    ),
  ];

  static List<NavDestination> visibleDestinations(Me me) {
    return destinations.where((item) => item.isAllowed(me)).toList();
  }

  static NavDestination? byPath(String path) {
    final normalized = normalizePath(path);
    for (final item in destinations) {
      if (item.path == normalized) {
        return item;
      }
    }
    return null;
  }

  static String normalizePath(String? path) {
    if (path == null || path.isEmpty || path == '/') {
      return AppPaths.home;
    }
    if (path.endsWith('/') && path.length > 1) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  /// Whether [path] is a known module route.
  static bool isKnownPath(String path) => byPath(path) != null;
}
