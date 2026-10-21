import 'package:equatable/equatable.dart';

enum ServiceAvailability {
  /// `/api/health` returned ok.
  healthy,

  /// Confirmed maintenance (HTTP 503 and/or `MAINTENANCE` code).
  maintenance,

  /// Network failure talking to health (distinct from maintenance).
  unreachable,
}

/// Parsed view of `GET /api/health` (and defensive 503 payloads).
class HealthStatus extends Equatable {
  const HealthStatus({
    required this.availability,
    this.message,
    this.reason,
    this.since,
    this.retryAfterSeconds,
    this.serverTime,
  });

  final ServiceAvailability availability;
  final String? message;
  final String? reason;
  final DateTime? since;
  final int? retryAfterSeconds;
  final DateTime? serverTime;

  bool get isHealthy => availability == ServiceAvailability.healthy;
  bool get isMaintenance => availability == ServiceAvailability.maintenance;
  bool get isUnreachable => availability == ServiceAvailability.unreachable;

  @override
  List<Object?> get props => [
    availability,
    message,
    reason,
    since,
    retryAfterSeconds,
    serverTime,
  ];
}
