import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'value_objects.dart';

class TripCounts extends Equatable {
  const TripCounts({
    required this.requested,
    required this.assigned,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
    required this.active,
    required this.cancellationRate,
  });

  final int requested;
  final int assigned;
  final int inProgress;
  final int completed;
  final int cancelled;
  final int active;
  final double cancellationRate;

  @override
  List<Object?> get props => [
    requested,
    assigned,
    inProgress,
    completed,
    cancelled,
    active,
    cancellationRate,
  ];
}

class DriverCounts extends Equatable {
  const DriverCounts({
    required this.available,
    required this.onTrip,
    required this.offline,
    required this.total,
  });

  final int available;
  final int onTrip;
  final int offline;
  final int total;

  @override
  List<Object?> get props => [available, onTrip, offline, total];
}

class SeriesPoint extends Equatable {
  const SeriesPoint({
    required this.bucket,
    required this.total,
    required this.completed,
    required this.cancelled,
  });

  final DateTime bucket;
  final int total;
  final int completed;
  final int cancelled;

  @override
  List<Object?> get props => [bucket, total, completed, cancelled];
}

class Kpis extends Equatable {
  const Kpis({
    required this.range,
    required this.generatedAt,
    required this.trips,
    required this.revenue,
    required this.averageFare,
    required this.refunds,
    required this.drivers,
    required this.openAlerts,
    this.cityId,
    this.series = const [],
  });

  final KpiRange range;
  final String? cityId;
  final DateTime generatedAt;
  final TripCounts trips;
  final List<Money> revenue;
  final List<Money> averageFare;
  final List<Money> refunds;
  final DriverCounts drivers;
  final int openAlerts;
  final List<SeriesPoint> series;

  @override
  List<Object?> get props => [
    range,
    cityId,
    generatedAt,
    trips,
    revenue,
    averageFare,
    refunds,
    drivers,
    openAlerts,
    series,
  ];
}

class AdminUser extends Equatable {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.banned,
    required this.createdAt,
    this.cityId,
    this.banReason,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? cityId;
  final bool banned;
  final String? banReason;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    role,
    cityId,
    banned,
    banReason,
    createdAt,
  ];
}
