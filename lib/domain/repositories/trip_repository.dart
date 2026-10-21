import '../entities/enums.dart';
import '../entities/trip.dart';
import '../entities/value_objects.dart';

abstract class TripRepository {
  Future<CursorPage<Trip>> watchBoard({
    List<TripStatus>? status,
    String? cityId,
    String? search,
    DateTime? from,
    DateTime? to,
    int first = 20,
    String? after,
  });

  Future<Trip> getById(String id);

  Future<Trip> create({
    required String riderId,
    required Place pickup,
    required Place dropoff,
  });

  Future<Trip> assign({required String tripId, required String driverId});

  Future<Trip> cancel({required String tripId, required String reason});

  Future<Trip> refund({
    required String tripId,
    required double amount,
    required String reason,
  });
}
