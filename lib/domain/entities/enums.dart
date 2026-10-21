enum AppRole { superAdmin, opsManager, dispatcher, support, viewer }

enum DriverStatus { offline, available, onTrip }

enum TripStatus { requested, assigned, inProgress, completed, cancelled }

enum AlertType { sos, noDriverAvailable, highDemand, refundIssued }

enum AlertSeverity { info, warning, critical }

enum KpiRange { last24h, last7d }

enum MessageDirection { toDriver, fromDriver }

AppRole parseAppRole(String raw) {
  return switch (raw.toUpperCase()) {
    'SUPER_ADMIN' => AppRole.superAdmin,
    'OPS_MANAGER' => AppRole.opsManager,
    'DISPATCHER' => AppRole.dispatcher,
    'SUPPORT' => AppRole.support,
    'VIEWER' => AppRole.viewer,
    _ => throw FormatException('Unknown role: $raw'),
  };
}

DriverStatus parseDriverStatus(String raw) {
  return switch (raw.toLowerCase()) {
    'offline' => DriverStatus.offline,
    'available' => DriverStatus.available,
    'on_trip' => DriverStatus.onTrip,
    _ => throw FormatException('Unknown driver status: $raw'),
  };
}

TripStatus parseTripStatus(String raw) {
  return switch (raw.toLowerCase()) {
    'requested' => TripStatus.requested,
    'assigned' => TripStatus.assigned,
    'in_progress' => TripStatus.inProgress,
    'completed' => TripStatus.completed,
    'cancelled' => TripStatus.cancelled,
    _ => throw FormatException('Unknown trip status: $raw'),
  };
}

AlertType parseAlertType(String raw) {
  return switch (raw.toLowerCase()) {
    'sos' => AlertType.sos,
    'no_driver_available' => AlertType.noDriverAvailable,
    'high_demand' => AlertType.highDemand,
    'refund_issued' => AlertType.refundIssued,
    _ => throw FormatException('Unknown alert type: $raw'),
  };
}

AlertSeverity parseAlertSeverity(String raw) {
  return switch (raw.toLowerCase()) {
    'info' => AlertSeverity.info,
    'warning' => AlertSeverity.warning,
    'critical' => AlertSeverity.critical,
    _ => throw FormatException('Unknown alert severity: $raw'),
  };
}

KpiRange parseKpiRange(String raw) {
  return switch (raw.toLowerCase()) {
    'last_24h' => KpiRange.last24h,
    'last_7d' => KpiRange.last7d,
    _ => throw FormatException('Unknown KPI range: $raw'),
  };
}

MessageDirection parseMessageDirection(String raw) {
  return switch (raw.toLowerCase()) {
    'to_driver' => MessageDirection.toDriver,
    'from_driver' => MessageDirection.fromDriver,
    _ => throw FormatException('Unknown message direction: $raw'),
  };
}

String tripStatusToGraphQl(TripStatus status) {
  return switch (status) {
    TripStatus.requested => 'REQUESTED',
    TripStatus.assigned => 'ASSIGNED',
    TripStatus.inProgress => 'IN_PROGRESS',
    TripStatus.completed => 'COMPLETED',
    TripStatus.cancelled => 'CANCELLED',
  };
}

String driverStatusToGraphQl(DriverStatus status) {
  return switch (status) {
    DriverStatus.offline => 'OFFLINE',
    DriverStatus.available => 'AVAILABLE',
    DriverStatus.onTrip => 'ON_TRIP',
  };
}

String alertTypeToGraphQl(AlertType type) {
  return switch (type) {
    AlertType.sos => 'SOS',
    AlertType.noDriverAvailable => 'NO_DRIVER_AVAILABLE',
    AlertType.highDemand => 'HIGH_DEMAND',
    AlertType.refundIssued => 'REFUND_ISSUED',
  };
}

String alertSeverityToGraphQl(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.info => 'INFO',
    AlertSeverity.warning => 'WARNING',
    AlertSeverity.critical => 'CRITICAL',
  };
}

String kpiRangeToGraphQl(KpiRange range) {
  return switch (range) {
    KpiRange.last24h => 'LAST_24H',
    KpiRange.last7d => 'LAST_7D',
  };
}
