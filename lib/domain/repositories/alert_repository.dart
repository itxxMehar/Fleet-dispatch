import '../entities/alert.dart';
import '../entities/enums.dart';
import '../entities/value_objects.dart';

abstract class AlertRepository {
  Future<CursorPage<OpsAlert>> list({
    bool? acknowledged,
    List<AlertType>? type,
    List<AlertSeverity>? severity,
    String? cityId,
    int first = 20,
    String? after,
  });

  Future<OpsAlert> acknowledge(String id);
}
