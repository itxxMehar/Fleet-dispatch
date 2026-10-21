import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/session.dart';

/// A shell navigation entry gated by a documented API permission.
///
/// When [resource] / [action] are null, the destination is available to any
/// authenticated user (e.g. the home overview). Visibility must never be
/// derived from role names.
class NavDestination extends Equatable {
  const NavDestination({
    required this.id,
    required this.path,
    required this.label,
    required this.icon,
    this.resource,
    this.action,
  });

  final String id;
  final String path;
  final String label;
  final IconData icon;

  /// Permission resource from `/api/me` (e.g. `kpi`, `trip`). Null = always.
  final String? resource;

  /// Permission action from `/api/me` (e.g. `read`, `track`). Null = always.
  final String? action;

  bool isAllowed(Me me) {
    final resourceName = resource;
    final actionName = action;
    if (resourceName == null || actionName == null) {
      return true;
    }
    return me.can(resourceName, actionName);
  }

  @override
  List<Object?> get props => [id, path, label, resource, action];
}
