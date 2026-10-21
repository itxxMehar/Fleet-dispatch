import '../../core/auth/token_store.dart';
import '../../core/error/api_exception.dart';
import '../../core/network/rest_client.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../mappers/entity_mappers.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required RestClient restClient,
    required TokenStore tokenStore,
  }) : _rest = restClient,
       _tokens = tokenStore;

  final RestClient _rest;
  final TokenStore _tokens;

  @override
  Future<SessionUser> signIn({
    required String email,
    required String password,
  }) async {
    final body = await _rest.post(
      '/api/auth/sign-in/email',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    if (body == null || body['token'] is! String || body['user'] is! Map) {
      throw const ApiException(
        code: 'UNAUTHENTICATED',
        message: 'Sign-in did not return a session token.',
      );
    }
    // Persist the JSON `token` only — never the password.
    await _tokens.save(body['token'] as String);
    return mapSessionUser(Map<String, dynamic>.from(body['user'] as Map));
  }

  @override
  Future<void> signOut() async {
    try {
      if (_tokens.hasToken) {
        await _rest.post('/api/auth/sign-out', body: const <String, dynamic>{});
      }
    } finally {
      // Always clear local session, even if the revoke request fails.
      await _tokens.clear();
    }
  }

  @override
  Future<SessionUser?> getSession() async {
    if (!_tokens.hasToken) {
      return null;
    }
    final body = await _rest.get('/api/auth/get-session');
    if (body == null || body['user'] is! Map) {
      await _tokens.clear();
      return null;
    }
    return mapSessionUser(Map<String, dynamic>.from(body['user'] as Map));
  }
}
