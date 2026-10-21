import 'package:equatable/equatable.dart';

import 'city.dart';
import 'driver.dart';
import 'enums.dart';
import 'rider.dart';
import 'value_objects.dart';

class Trip extends Equatable {
  const Trip({
    required this.id,
    required this.cityId,
    required this.riderId,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.fare,
    required this.refunded,
    required this.requestedAt,
    this.driverId,
    this.refundReason,
    this.cancelReason,
    this.cancelledBy,
    this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.updatedAt,
    this.city,
    this.rider,
    this.driver,
  });

  final String id;
  final String cityId;
  final String riderId;
  final String? driverId;
  final TripStatus status;
  final Place pickup;
  final Place dropoff;
  final double distanceKm;
  final Money fare;
  final Money refunded;
  final String? refundReason;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime requestedAt;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? updatedAt;
  final City? city;
  final Rider? rider;
  final Driver? driver;

  @override
  List<Object?> get props => [
    id,
    cityId,
    riderId,
    driverId,
    status,
    pickup,
    dropoff,
    distanceKm,
    fare,
    refunded,
    refundReason,
    cancelReason,
    cancelledBy,
    requestedAt,
    assignedAt,
    startedAt,
    completedAt,
    cancelledAt,
    updatedAt,
  ];
}
