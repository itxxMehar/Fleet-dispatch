import '../../core/network/graphql_client.dart';
import '../../core/network/rest_client.dart';
import '../../domain/entities/driver.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/value_objects.dart';
import '../../domain/repositories/driver_repository.dart';
import '../graphql/documents.dart';
import '../mappers/entity_mappers.dart';

class DriverRepositoryImpl implements DriverRepository {
  DriverRepositoryImpl({
    required RestClient restClient,
    required GraphQlClient graphQlClient,
  }) : _rest = restClient,
       _graphQl = graphQlClient;

  final RestClient _rest;
  final GraphQlClient _graphQl;

  @override
  Future<CursorPage<Driver>> list({
    List<DriverStatus>? status,
    String? cityId,
    String? search,
    int first = 20,
    String? after,
  }) async {
    final data = await _graphQl.query(
      document: driversQuery,
      operationName: 'Drivers',
      variables: {
        'first': first,
        'after': ?after,
        'filter': {
          'cityId': ?cityId,
          'search': ?search,
          'status': ?status?.map(driverStatusToGraphQl).toList(),
        },
      },
    );
    return mapConnection(
      Map<String, dynamic>.from(data['drivers'] as Map),
      mapDriver,
    );
  }

  @override
  Future<Driver> getById(String id) async {
    final data = await _graphQl.query(
      document: driverQuery,
      operationName: 'Driver',
      variables: {'id': id},
    );
    return mapDriver(Map<String, dynamic>.from(data['driver'] as Map));
  }

  @override
  Future<Driver> create({
    required String cityId,
    required String name,
    required String phone,
    required Vehicle vehicle,
  }) async {
    final body = await _rest.post(
      '/api/drivers',
      body: {
        'cityId': cityId,
        'name': name,
        'phone': phone,
        'vehicle': {
          'make': vehicle.make,
          'model': vehicle.model,
          'plate': vehicle.plate,
          'color': vehicle.color,
        },
      },
    );
    return mapDriver(body!);
  }

  @override
  Future<Driver> update({
    required String id,
    String? name,
    String? phone,
    String? status,
    Vehicle? vehicle,
  }) async {
    final body = await _rest.patch(
      '/api/drivers/$id',
      body: {
        'name': ?name,
        'phone': ?phone,
        'status': ?status,
        if (vehicle != null)
          'vehicle': {
            'make': vehicle.make,
            'model': vehicle.model,
            'plate': vehicle.plate,
            'color': vehicle.color,
          },
      },
    );
    return mapDriver(body!);
  }
}
