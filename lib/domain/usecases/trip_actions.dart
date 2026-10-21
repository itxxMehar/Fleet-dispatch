import '../entities/driver.dart';
import '../entities/enums.dart';
import '../entities/trip.dart';
import '../entities/value_objects.dart';
import '../repositories/driver_repository.dart';
import '../repositories/trip_repository.dart';

class ListTrips {
  const ListTrips(this._trips);

  final TripRepository _trips;

  Future<CursorPage<Trip>> call({
    List<TripStatus>? status,
    String? cityId,
    String? search,
    DateTime? from,
    DateTime? to,
    int first = 20,
    String? after,
  }) {
    return _trips.watchBoard(
      status: status,
      cityId: cityId,
      search: search,
      from: from,
      to: to,
      first: first,
      after: after,
    );
  }
}

class GetTrip {
  const GetTrip(this._trips);

  final TripRepository _trips;

  Future<Trip> call(String id) => _trips.getById(id);
}

class AssignTrip {
  const AssignTrip(this._trips);

  final TripRepository _trips;

  Future<Trip> call({required String tripId, required String driverId}) {
    return _trips.assign(tripId: tripId, driverId: driverId);
  }
}

class CancelTrip {
  const CancelTrip(this._trips);

  final TripRepository _trips;

  Future<Trip> call({required String tripId, required String reason}) {
    return _trips.cancel(tripId: tripId, reason: reason);
  }
}

class RefundTrip {
  const RefundTrip(this._trips);

  final TripRepository _trips;

  Future<Trip> call({
    required String tripId,
    required double amount,
    required String reason,
  }) {
    return _trips.refund(tripId: tripId, amount: amount, reason: reason);
  }
}

class ListAvailableDrivers {
  const ListAvailableDrivers(this._drivers);

  final DriverRepository _drivers;

  Future<CursorPage<Driver>> call({String? cityId, int first = 50}) {
    return _drivers.list(
      status: const [DriverStatus.available],
      cityId: cityId,
      first: first,
    );
  }
}

/// Client-side refund checks. The server remains authoritative.
abstract final class RefundRules {
  static String? validate({
    required double amount,
    required Money fare,
    required Money refunded,
  }) {
    if (amount <= 0) {
      return 'Refund amount must be greater than zero.';
    }
    final remaining = fare.amount - refunded.amount;
    if (amount > remaining + 0.0001) {
      return 'Refund cannot exceed the remaining ${fare.currency} $remaining.';
    }
    return null;
  }

  static double remainingAmount(Money fare, Money refunded) {
    final value = fare.amount - refunded.amount;
    return value < 0 ? 0 : value;
  }
}
