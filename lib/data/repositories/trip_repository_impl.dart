import '../../core/network/graphql_client.dart';
import '../../core/network/rest_client.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/trip.dart';
import '../../domain/entities/value_objects.dart';
import '../../domain/repositories/trip_repository.dart';
import '../graphql/documents.dart';
import '../mappers/entity_mappers.dart';

class TripRepositoryImpl implements TripRepository {
  TripRepositoryImpl({
    required RestClient restClient,
    required GraphQlClient graphQlClient,
  }) : _rest = restClient,
       _graphQl = graphQlClient;

  final RestClient _rest;
  final GraphQlClient _graphQl;

  @override
  Future<CursorPage<Trip>> watchBoard({
    List<TripStatus>? status,
    String? cityId,
    String? search,
    DateTime? from,
    DateTime? to,
    int first = 20,
    String? after,
  }) async {
    final data = await _graphQl.query(
      document: tripsQuery,
      operationName: 'Trips',
      variables: {
        'first': first,
        'after': ?after,
        'filter': {
          'cityId': ?cityId,
          'search': ?search,
          'status': ?status?.map(tripStatusToGraphQl).toList(),
          'from': ?from?.toUtc().toIso8601String(),
          'to': ?to?.toUtc().toIso8601String(),
        },
      },
    );
    return mapConnection(
      Map<String, dynamic>.from(data['trips'] as Map),
      mapTrip,
    );
  }

  @override
  Future<Trip> getById(String id) async {
    final data = await _graphQl.query(
      document: tripQuery,
      operationName: 'Trip',
      variables: {'id': id},
    );
    return mapTrip(Map<String, dynamic>.from(data['trip'] as Map));
  }

  @override
  Future<Trip> create({
    required String riderId,
    required Place pickup,
    required Place dropoff,
  }) async {
    final body = await _rest.post(
      '/api/trips',
      body: {
        'riderId': riderId,
        'pickup': {
          'address': pickup.address,
          'lat': pickup.lat,
          'lng': pickup.lng,
        },
        'dropoff': {
          'address': dropoff.address,
          'lat': dropoff.lat,
          'lng': dropoff.lng,
        },
      },
    );
    return mapTrip(body!);
  }

  @override
  Future<Trip> assign({
    required String tripId,
    required String driverId,
  }) async {
    final body = await _rest.post(
      '/api/trips/$tripId/assign',
      body: {'driverId': driverId},
    );
    return mapTrip(body!);
  }

  @override
  Future<Trip> cancel({required String tripId, required String reason}) async {
    final body = await _rest.post(
      '/api/trips/$tripId/cancel',
      body: {'reason': reason},
    );
    return mapTrip(body!);
  }

  @override
  Future<Trip> refund({
    required String tripId,
    required double amount,
    required String reason,
  }) async {
    final body = await _rest.post(
      '/api/trips/$tripId/refund',
      body: {'amount': amount, 'reason': reason},
    );
    return mapTrip(body!);
  }
}
