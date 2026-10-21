import 'token_persistence.dart';

/// Holds the session token in memory and mirrors it to [TokenPersistence].
///
/// Never stores passwords. Never log [token].
class TokenStore {
  TokenStore({TokenPersistence? persistence})
    : _persistence = persistence ?? MemoryTokenPersistence();

  final TokenPersistence _persistence;
  String? _token;

  String? get token => _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Loads any previously persisted token into memory (browser refresh).
  Future<void> restore() async {
    _token = await _persistence.read();
  }

  Future<void> save(String token) async {
    _token = token;
    await _persistence.write(token);
  }

  Future<void> clear() async {
    _token = null;
    await _persistence.delete();
  }
}
