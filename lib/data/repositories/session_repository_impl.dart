import '../../core/network/rest_client.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/session_repository.dart';
import '../mappers/entity_mappers.dart';

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._rest);

  final RestClient _rest;

  @override
  Future<Me> getMe() async {
    final body = await _rest.get('/api/me');
    return mapMe(body!);
  }
}
