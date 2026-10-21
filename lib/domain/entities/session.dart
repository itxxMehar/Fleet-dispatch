import 'package:equatable/equatable.dart';

import 'city.dart';
import 'enums.dart';
import 'value_objects.dart';

class SessionUser extends Equatable {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.banned,
    this.cityId,
    this.banReason,
  });

  final String id;
  final String name;
  final String email;
  final AppRole role;
  final bool banned;
  final String? cityId;
  final String? banReason;

  @override
  List<Object?> get props => [id, name, email, role, banned, cityId, banReason];
}

class Me extends Equatable {
  const Me({
    required this.user,
    required this.role,
    required this.roleDescription,
    required this.permissions,
    this.city,
  });

  final SessionUser user;
  final AppRole role;
  final String roleDescription;
  final City? city;
  final PermissionSet permissions;

  bool can(String resource, String action) => permissions.can(resource, action);

  @override
  List<Object?> get props => [
    user,
    role,
    roleDescription,
    city,
    permissions.asMap,
  ];
}
