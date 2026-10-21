import '../entities/session.dart';

abstract class SessionRepository {
  Future<Me> getMe();
}
