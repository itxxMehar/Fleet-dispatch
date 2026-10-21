import 'package:shared_preferences/shared_preferences.dart';

/// Browser-compatible persistence for the session token only.
///
/// On Flutter Web, [SharedPreferencesTokenPersistence] uses `window.localStorage`.
/// That is readable by JavaScript on the same origin — not equivalent to an
/// HttpOnly cookie. Acceptable for this sandbox assessment.
abstract class TokenPersistence {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

class MemoryTokenPersistence implements TokenPersistence {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String token) async => _value = token;

  @override
  Future<void> delete() async => _value = null;
}

class SharedPreferencesTokenPersistence implements TokenPersistence {
  SharedPreferencesTokenPersistence(this._prefs);

  static const storageKey = 'badrgo_session_token';

  final SharedPreferences _prefs;

  @override
  Future<String?> read() async {
    final value = _prefs.getString(storageKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  @override
  Future<void> write(String token) => _prefs.setString(storageKey, token);

  @override
  Future<void> delete() => _prefs.remove(storageKey);
}
