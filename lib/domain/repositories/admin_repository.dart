import '../entities/city.dart';
import '../entities/kpis.dart';
import '../entities/value_objects.dart';

abstract class AdminRepository {
  Future<PageResult<AdminUser>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? role,
    String? cityId,
  });

  Future<AdminUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? cityId,
  });

  Future<List<City>> listCities();
}
