import 'api_exception.dart';

ApiException parseRestFailure({
  required int statusCode,
  required Object? body,
}) {
  if (body is Map<String, dynamic>) {
    final error = body['error'];
    if (error is Map<String, dynamic> && error['code'] is String) {
      return ApiException(
        code: error['code'] as String,
        message: (error['message'] as String?) ?? 'Request failed.',
        details: error['details'],
        statusCode: statusCode,
      );
    }

    // Better Auth sign-in uses `{ code, message }` without an `error` wrapper.
    if (body['code'] is String && body['message'] is String) {
      return ApiException(
        code: body['code'] as String,
        message: body['message'] as String,
        details: body['details'],
        statusCode: statusCode,
      );
    }
  }

  return ApiException(
    code: _fallbackCode(statusCode),
    message: 'Request failed with status $statusCode.',
    details: body,
    statusCode: statusCode,
  );
}

/// Throws [ApiException] when GraphQL `errors` is non-empty.
void throwIfGraphQlErrors(Map<String, dynamic> body) {
  final errors = body['errors'];
  if (errors is! List || errors.isEmpty) {
    return;
  }

  final first = errors.first;
  if (first is! Map) {
    throw const ApiException(
      code: 'GRAPHQL_ERROR',
      message: 'GraphQL request failed.',
    );
  }

  final map = Map<String, dynamic>.from(first);
  final extensions = map['extensions'] is Map
      ? Map<String, dynamic>.from(map['extensions'] as Map)
      : const <String, dynamic>{};
  final path = map['path'] is List ? (map['path'] as List).join('.') : null;

  throw ApiException(
    code: (extensions['code'] as String?) ?? 'GRAPHQL_ERROR',
    message: (map['message'] as String?) ?? 'GraphQL request failed.',
    details: {
      if (extensions.isNotEmpty) 'extensions': extensions,
      'errors': errors,
    },
    path: path,
    statusCode: 200,
  );
}

String _fallbackCode(int statusCode) {
  return switch (statusCode) {
    401 => 'UNAUTHENTICATED',
    403 => 'FORBIDDEN',
    404 => 'NOT_FOUND',
    409 => 'CONFLICT',
    422 => 'VALIDATION_FAILED',
    503 => 'UNAVAILABLE',
    _ => 'INTERNAL',
  };
}
