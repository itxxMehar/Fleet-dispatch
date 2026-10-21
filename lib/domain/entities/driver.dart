import 'package:equatable/equatable.dart';

import 'city.dart';
import 'enums.dart';
import 'trip.dart';
import 'value_objects.dart';

class DriverLocation extends Equatable {
  const DriverLocation({
    required this.lat,
    required this.lng,
    required this.heading,
  });

  final double lat;
  final double lng;
  final double heading;

  @override
  List<Object?> get props => [lat, lng, heading];
}

class Driver extends Equatable {
  const Driver({
    required this.id,
    required this.cityId,
    required this.name,
    required this.phone,
    required this.status,
    required this.rating,
    required this.vehicle,
    required this.createdAt,
    this.location,
    this.lastSeenAt,
    this.city,
    this.updatedAt,
    this.currentTrip,
  });

  final String id;
  final String cityId;
  final String name;
  final String phone;
  final DriverStatus status;
  final double rating;
  final Vehicle vehicle;
  final DriverLocation? location;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final City? city;
  final Trip? currentTrip;

  @override
  List<Object?> get props => [
    id,
    cityId,
    name,
    phone,
    status,
    rating,
    vehicle,
    location,
    lastSeenAt,
    createdAt,
    updatedAt,
    city,
    currentTrip,
  ];
}

class DriverMessage extends Equatable {
  const DriverMessage({
    required this.id,
    required this.driverId,
    required this.cityId,
    required this.direction,
    required this.body,
    required this.createdAt,
    this.sentBy,
  });

  final String id;
  final String driverId;
  final String cityId;
  final MessageDirection direction;
  final String body;
  final String? sentBy;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    driverId,
    cityId,
    direction,
    body,
    sentBy,
    createdAt,
  ];
}
