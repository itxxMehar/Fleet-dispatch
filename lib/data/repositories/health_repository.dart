import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/error/api_exception.dart';
import '../../core/network/json_codec.dart';
import '../../domain/entities/health_status.dart';

/// Unauthenticated health checks — never clears the session on 503.
class HealthRepository {
  HealthRepository({required AppConfig config, http.Client? httpClient})
    : _config = config,
      _http = httpClient ?? http.Client();

  final AppConfig _config;
  final http.Client _http;

  Future<HealthStatus> check() async {
    final uri = _config.restUri('/api/health');
    final http.Response response;
    try {
      response = await _http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
    } on http.ClientException catch (error) {
      return HealthStatus(
        availability: ServiceAvailability.unreachable,
        message: error.message,
      );
    } catch (_) {
      return const HealthStatus(
        availability: ServiceAvailability.unreachable,
        message: 'Unable to reach the health endpoint.',
      );
    }

    final decoded = decodeJsonMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final ok = decoded?['ok'] == true;
      return HealthStatus(
        availability: ok
            ? ServiceAvailability.healthy
            : ServiceAvailability.maintenance,
        message: decoded?['message'] as String?,
        reason: decoded?['reason'] as String?,
        since: _readDate(decoded?['since']),
        retryAfterSeconds: _readInt(decoded?['retryAfterSeconds']),
        serverTime: _readDate(decoded?['time']),
      );
    }

    if (response.statusCode == 503) {
      return _parseMaintenance(decoded, response.body);
    }

    return HealthStatus(
      availability: ServiceAvailability.unreachable,
      message: 'Health check failed with status ${response.statusCode}.',
    );
  }

  HealthStatus _parseMaintenance(Map<String, dynamic>? decoded, String raw) {
    // OpenAPI currently documents only 200 for /api/health. Parse MAINTENANCE
    // fields defensively when the sandbox (or future contract) returns them.
    String? code;
    String? message;
    String? reason;
    DateTime? since;
    int? retryAfter;
    Object? details;

    if (decoded != null) {
      code = decoded['code'] as String?;
      message = decoded['message'] as String?;
      reason = decoded['reason'] as String?;
      since = _readDate(decoded['since']);
      retryAfter = _readInt(decoded['retryAfterSeconds']);

      final error = decoded['error'];
      if (error is Map) {
        final map = Map<String, dynamic>.from(error);
        code ??= map['code'] as String?;
        message ??= map['message'] as String?;
        details = map['details'];
      }
      if (details is Map) {
        final map = Map<String, dynamic>.from(details);
        reason ??= map['reason'] as String?;
        since ??= _readDate(map['since']);
        retryAfter ??= _readInt(map['retryAfterSeconds']);
        message ??= map['message'] as String?;
      }
    }

    final isMaintenance =
        code == 'MAINTENANCE' ||
        code == 'UNAVAILABLE' ||
        responseLooksLikeMaintenance(raw);

    return HealthStatus(
      availability: isMaintenance
          ? ServiceAvailability.maintenance
          : ServiceAvailability.unreachable,
      message:
          message ??
          'The service is temporarily unavailable. Please try again shortly.',
      reason: reason,
      since: since,
      retryAfterSeconds: retryAfter,
    );
  }

  static bool responseLooksLikeMaintenance(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('maintenance') || lower.contains('unavailable');
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) {
      return null;
    }
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

/// Maps a health failure into an [ApiException] for callers that need it.
ApiException healthToException(HealthStatus status) {
  return ApiException(
    code: status.isMaintenance ? 'MAINTENANCE' : 'NETWORK',
    message: status.message ?? 'Service unavailable',
    details: {
      if (status.reason != null) 'reason': status.reason,
      if (status.since != null) 'since': status.since!.toIso8601String(),
      if (status.retryAfterSeconds != null)
        'retryAfterSeconds': status.retryAfterSeconds,
    },
    statusCode: status.isMaintenance ? 503 : null,
  );
}
