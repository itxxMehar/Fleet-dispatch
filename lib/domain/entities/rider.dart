import 'package:equatable/equatable.dart';

class Rider extends Equatable {
  const Rider({
    required this.id,
    required this.cityId,
    required this.name,
    required this.phone,
    required this.rating,
    required this.createdAt,
    this.email,
    this.updatedAt,
    this.tripCount,
  });

  final String id;
  final String cityId;
  final String name;
  final String phone;
  final String? email;
  final double rating;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? tripCount;

  @override
  List<Object?> get props => [
    id,
    cityId,
    name,
    phone,
    email,
    rating,
    createdAt,
    updatedAt,
    tripCount,
  ];
}
