import '../../core/network/rest_client.dart';
import '../../domain/entities/driver.dart';
import '../../domain/repositories/chat_repository.dart';
import '../mappers/entity_mappers.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._rest);

  final RestClient _rest;

  @override
  Future<List<DriverMessage>> history({
    required String driverId,
    int limit = 50,
  }) async {
    final body = await _rest.get(
      '/api/drivers/$driverId/messages',
      query: {'limit': '$limit'},
    );
    final data = body!['data'] as List;
    return data
        .map((e) => mapDriverMessage(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
