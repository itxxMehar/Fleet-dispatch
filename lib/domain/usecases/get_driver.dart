import '../entities/driver.dart';
import '../repositories/driver_repository.dart';

class GetDriver {
  const GetDriver(this._repository);

  final DriverRepository _repository;

  Future<Driver> call(String id) => _repository.getById(id);
}
