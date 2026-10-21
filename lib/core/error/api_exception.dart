class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
    this.path,
  });

  /// REST `error.code` or GraphQL `errors[].extensions.code`.
  final String code;
  final String message;
  final Object? details;
  final int? statusCode;
  final String? path;

  bool get isUnauthenticated => code == 'UNAUTHENTICATED';
  bool get isForbidden => code == 'FORBIDDEN';
  bool get isNotFound => code == 'NOT_FOUND';
  bool get isValidation =>
      code == 'VALIDATION_FAILED' || code == 'GRAPHQL_VALIDATION_FAILED';
  bool get isConflict => code == 'CONFLICT' || code == 'INVALID_STATE';
  bool get isNetwork => code == 'NETWORK';
  bool get isUnavailable =>
      code == 'UNAVAILABLE' || code == 'MAINTENANCE' || statusCode == 503;

  bool get isMaintenance => code == 'MAINTENANCE';

  @override
  String toString() => 'ApiException($code, $message)';
}
