import '../../core/network/graphql_client.dart';
import '../../core/network/rest_client.dart';
import '../../domain/entities/alert.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/value_objects.dart';
import '../../domain/repositories/alert_repository.dart';
import '../graphql/documents.dart';
import '../mappers/entity_mappers.dart';

class AlertRepositoryImpl implements AlertRepository {
  AlertRepositoryImpl({
    required RestClient restClient,
    required GraphQlClient graphQlClient,
  }) : _rest = restClient,
       _graphQl = graphQlClient;

  final RestClient _rest;
  final GraphQlClient _graphQl;

  @override
  Future<CursorPage<OpsAlert>> list({
    bool? acknowledged,
    List<AlertType>? type,
    List<AlertSeverity>? severity,
    String? cityId,
    int first = 20,
    String? after,
  }) async {
    final data = await _graphQl.query(
      document: alertsQuery,
      operationName: 'Alerts',
      variables: {
        'first': first,
        'after': ?after,
        'filter': {
          'cityId': ?cityId,
          'acknowledged': ?acknowledged,
          'type': ?type?.map(alertTypeToGraphQl).toList(),
          'severity': ?severity?.map(alertSeverityToGraphQl).toList(),
        },
      },
    );
    return mapConnection(
      Map<String, dynamic>.from(data['alerts'] as Map),
      mapAlert,
    );
  }

  @override
  Future<OpsAlert> acknowledge(String id) async {
    final body = await _rest.post('/api/alerts/$id/acknowledge');
    return mapAlert(body!);
  }
}
