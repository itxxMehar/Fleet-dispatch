import '../../domain/entities/enums.dart';
import '../../domain/entities/session.dart';

/// Formats role and city labels from the authoritative `/api/me` payload.
abstract final class SessionContextLabel {
  static String roleWire(AppRole role) {
    return switch (role) {
      AppRole.superAdmin => 'super_admin',
      AppRole.opsManager => 'ops_manager',
      AppRole.dispatcher => 'dispatcher',
      AppRole.support => 'support',
      AppRole.viewer => 'viewer',
    };
  }

  /// Prefer the API `roleDescription` when present; fall back to the wire role.
  static String roleDisplay(Me me) {
    final description = me.roleDescription.trim();
    if (description.isNotEmpty) {
      return description;
    }
    return roleWire(me.role);
  }

  /// City name when scoped; "All cities" when `city` is null (super_admin).
  static String cityDisplay(Me me) {
    final city = me.city;
    if (city != null) {
      return city.name;
    }
    return 'All cities';
  }

  static bool hasAllCitiesScope(Me me) => me.city == null;
}
