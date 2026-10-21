import '../entities/enums.dart';
import '../entities/kpis.dart';

abstract class KpiRepository {
  Future<Kpis> getKpis({String? cityId, KpiRange range = KpiRange.last24h});
}
