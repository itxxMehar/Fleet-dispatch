import '../entities/session.dart';
import '../repositories/session_repository.dart';

class GetMe {
  const GetMe(this._sessionRepository);

  final SessionRepository _sessionRepository;

  Future<Me> call() => _sessionRepository.getMe();
}
