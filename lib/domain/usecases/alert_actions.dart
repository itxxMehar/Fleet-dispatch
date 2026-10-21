import '../entities/alert.dart';
import '../entities/enums.dart';
import '../entities/value_objects.dart';
import '../repositories/alert_repository.dart';

class ListAlerts {
  const ListAlerts(this._repository);

  final AlertRepository _repository;

  Future<CursorPage<OpsAlert>> call({
    bool? acknowledged,
    List<AlertType>? type,
    List<AlertSeverity>? severity,
    String? cityId,
    int first = 20,
    String? after,
  }) {
    return _repository.list(
      acknowledged: acknowledged,
      type: type,
      severity: severity,
      cityId: cityId,
      first: first,
      after: after,
    );
  }
}

class AcknowledgeAlert {
  const AcknowledgeAlert(this._repository);

  final AlertRepository _repository;

  Future<OpsAlert> call(String id) => _repository.acknowledge(id);
}
