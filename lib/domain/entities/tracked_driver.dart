import 'package:equatable/equatable.dart';

import 'enums.dart';

/// A live map marker from the WebSocket `drivers.locations` snapshot.
class TrackedDriver extends Equatable {
  const TrackedDriver({
    required this.id,
    required this.cityId,
    required this.name,
    required this.status,
    required this.lat,
    required this.lng,
    required this.heading,
    this.lastSeenAt,
  });

  final String id;
  final String cityId;
  final String name;
  final DriverStatus status;
  final double lat;
  final double lng;
  final double heading;
  final DateTime? lastSeenAt;

  @override
  List<Object?> get props => [
    id,
    cityId,
    name,
    status,
    lat,
    lng,
    heading,
    lastSeenAt,
  ];
}
