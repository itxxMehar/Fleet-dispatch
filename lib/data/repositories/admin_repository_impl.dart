import '../../core/network/rest_client.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/kpis.dart';
import '../../domain/entities/value_objects.dart';
import '../../domain/repositories/admin_repository.dart';
import '../mappers/entity_mappers.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._rest);

  final RestClient _rest;

  @override
  Future<PageResult<AdminUser>> listUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? role,
    String? cityId,
  }) async {
    final body = await _rest.get(
      '/api/users',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        'search': ?search,
        'role': ?role,
        'cityId': ?cityId,
      },
    );
    return mapPage(body!, mapAdminUser);
  }

  @override
  Future<AdminUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? cityId,
  }) async {
    final body = await _rest.post(
      '/api/users',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'cityId': ?cityId,
      },
    );
    return mapAdminUser(body!);
  }

  @override
  Future<List<City>> listCities() async {
    final body = await _rest.get('/api/cities');
    final data = body!['data'] as List;
    return data
        .map((e) => mapCity(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
