import '../../core/network/graphql_client.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/kpis.dart';
import '../../domain/repositories/kpi_repository.dart';
import '../graphql/documents.dart';
import '../mappers/entity_mappers.dart';

class KpiRepositoryImpl implements KpiRepository {
  KpiRepositoryImpl(this._graphQl);

  final GraphQlClient _graphQl;

  @override
  Future<Kpis> getKpis({
    String? cityId,
    KpiRange range = KpiRange.last24h,
  }) async {
    final data = await _graphQl.query(
      document: kpisQuery,
      operationName: 'Kpis',
      variables: {'cityId': ?cityId, 'range': kpiRangeToGraphQl(range)},
    );
    return mapKpis(Map<String, dynamic>.from(data['kpis'] as Map));
  }
}
