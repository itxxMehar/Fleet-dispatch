import 'package:equatable/equatable.dart';

import 'value_objects.dart';

class City extends Equatable {
  const City({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.currency,
    required this.timezone,
    required this.center,
    required this.baseFare,
    required this.perKm,
    this.createdAt,
    this.activeTrips,
    this.availableDrivers,
  });

  final String id;
  final String name;
  final String countryCode;
  final String currency;
  final String timezone;
  final GeoPoint center;
  final double baseFare;
  final double perKm;
  final DateTime? createdAt;
  final int? activeTrips;
  final int? availableDrivers;

  @override
  List<Object?> get props => [
    id,
    name,
    countryCode,
    currency,
    timezone,
    center,
    baseFare,
    perKm,
    createdAt,
    activeTrips,
    availableDrivers,
  ];
}
