import '../entities/driver.dart';

abstract class ChatRepository {
  Future<List<DriverMessage>> history({
    required String driverId,
    int limit = 50,
  });
}
