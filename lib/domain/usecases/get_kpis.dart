import '../entities/enums.dart';
import '../entities/kpis.dart';
import '../repositories/kpi_repository.dart';

class GetKpis {
  const GetKpis(this._kpiRepository);

  final KpiRepository _kpiRepository;

  Future<Kpis> call({String? cityId, KpiRange range = KpiRange.last24h}) {
    return _kpiRepository.getKpis(cityId: cityId, range: range);
  }
}
