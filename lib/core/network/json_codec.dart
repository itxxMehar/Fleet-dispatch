import 'dart:convert';

Map<String, dynamic>? decodeJsonMap(String raw) {
  if (raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return {'data': decoded};
  } on FormatException {
    return null;
  }
}
