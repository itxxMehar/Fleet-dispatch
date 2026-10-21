import 'package:equatable/equatable.dart';

import 'enums.dart';

class OpsAlert extends Equatable {
  const OpsAlert({
    required this.id,
    required this.cityId,
    required this.type,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.cityName,
    this.tripId,
    this.driverId,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  final String id;
  final String cityId;
  final String? cityName;
  final AlertType type;
  final AlertSeverity severity;
  final String message;
  final String? tripId;
  final String? driverId;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;

  bool get isOpen => acknowledgedAt == null;

  @override
  List<Object?> get props => [
    id,
    cityId,
    cityName,
    type,
    severity,
    message,
    tripId,
    driverId,
    createdAt,
    acknowledgedAt,
    acknowledgedBy,
  ];
}
