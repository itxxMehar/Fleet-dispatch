DateTime? readDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.parse(value.toString());
}

DateTime readRequiredDate(Object? value) {
  final parsed = readDate(value);
  if (parsed == null) {
    throw const FormatException('Expected ISO-8601 timestamp.');
  }
  return parsed;
}

double readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Expected number, got $value');
}

int readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected int, got $value');
}

String gqlEnumToSnake(String raw) {
  return raw.toLowerCase();
}
