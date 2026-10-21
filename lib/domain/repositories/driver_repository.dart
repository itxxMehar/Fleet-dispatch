import '../entities/driver.dart';
import '../entities/enums.dart';
import '../entities/value_objects.dart';

abstract class DriverRepository {
  Future<CursorPage<Driver>> list({
    List<DriverStatus>? status,
    String? cityId,
    String? search,
    int first = 20,
    String? after,
  });

  Future<Driver> getById(String id);

  Future<Driver> create({
    required String cityId,
    required String name,
    required String phone,
    required Vehicle vehicle,
  });

  Future<Driver> update({
    required String id,
    String? name,
    String? phone,
    String? status,
    Vehicle? vehicle,
  });
}
