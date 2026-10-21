import 'dart:async';
import 'dart:convert';

import '../auth/token_store.dart';
import '../config/app_config.dart';
import 'sse_event.dart';
import 'sse_transport.dart';
import 'sse_transport_factory.dart';

/// Shared SSE hub for documented `/api/events` topics (`kpi`, `trips`, …).
///
/// Features call [subscribe] with the topics they need. One browser connection
/// is kept while any topic is active. [disconnect] runs on logout / session expiry.
///
/// **Auth limitation:** the documented API returns HTTP 401 for a missing/expired
/// token, but browser `EventSource` does not expose that status on its `error`
/// event. Generic transport errors are forwarded to listeners for reconnect UI
/// only — they must **not** trigger [SessionExpired]. Session
/// expiry continues to come from REST/GraphQL 401 and WebSocket close `4001`.
class OpsEventsClient {
  OpsEventsClient({
    required AppConfig config,
    required TokenStore tokenStore,
    SseTransport? transport,
  }) : _config = config,
       _tokens = tokenStore,
       _transport = transport ?? createPlatformSseTransport();

  final AppConfig _config;
  final TokenStore _tokens;
  final SseTransport _transport;

  // sync so feature listeners see events in the same turn as transport delivery
  // (avoids a second async hop that flaky unit tests and UI miss).
  final _outbound = StreamController<SseEvent>.broadcast(sync: true);
  final Map<String, int> _topicRefs = {};
  StreamSubscription<SseEvent>? _subscription;
  String? _lastEventId;
  bool _connecting = false;
  bool _openQueued = false;

  Stream<SseEvent> get events => _outbound.stream;

  /// Increments topic refs and (re)connects with the union of active topics.
  ///
  /// Completes after the connection attempt so listeners do not miss the first
  /// events (important for tests and immediate live updates).
  ///
  /// Returns the shared event stream. Callers must ignore unrelated event names
  /// (feature BLoCs already do). Topic filtering is applied at the connection URL via
  /// ref-counted [_topicRefs], not via an async `.where` hop.
  Future<Stream<SseEvent>> subscribe(Set<String> topics) async {
    for (final topic in topics) {
      _topicRefs[topic] = (_topicRefs[topic] ?? 0) + 1;
    }
    await _reconcileConnection();
    return _outbound.stream;
  }

  /// Decrements topic refs; closes the socket when nothing remains.
  Future<void> unsubscribe(Set<String> topics) async {
    for (final topic in topics) {
      final next = (_topicRefs[topic] ?? 0) - 1;
      if (next <= 0) {
        _topicRefs.remove(topic);
      } else {
        _topicRefs[topic] = next;
      }
    }
    await _reconcileConnection();
  }

  Future<void> disconnect() async {
    _topicRefs.clear();
    _openQueued = false;
    await _tearDown();
  }

  Future<void> _reconcileConnection() async {
    if (_topicRefs.isEmpty) {
      await _tearDown();
      return;
    }
    await _open();
  }

  Future<void> _open() async {
    if (_connecting) {
      _openQueued = true;
      return;
    }
    final token = _tokens.token;
    if (token == null || token.isEmpty) {
      await _tearDown();
      return;
    }

    _connecting = true;
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _transport.close();

      final topics = (_topicRefs.keys.toList()..sort()).join(',');
      final uri = _config.eventsUri(
        token: token,
        topics: topics,
        lastEventId: _lastEventId,
      );
      _subscription = _transport
          .connect(uri)
          .listen(
            (event) {
              if (event.id != null && event.id!.isNotEmpty) {
                _lastEventId = event.id;
              }
              if (!_outbound.isClosed) {
                _outbound.add(event);
              }
            },
            onError: (Object error, StackTrace stack) {
              // Forward for reconnect banners. Do not interpret as UNAUTHENTICATED —
              // EventSource gives no status code. Do not open a manual reconnect loop;
              // the browser EventSource reconnects on its own.
              if (!_outbound.isClosed) {
                _outbound.addError(error, stack);
              }
            },
            cancelOnError: false,
          );
    } finally {
      _connecting = false;
      if (_openQueued) {
        _openQueued = false;
        if (_topicRefs.isNotEmpty) {
          await _open();
        }
      }
    }
  }

  Future<void> _tearDown() async {
    await _subscription?.cancel();
    _subscription = null;
    await _transport.close();
  }

  /// Maps SSE event names to documented topic keys (for diagnostics / tests).
  static String? topicForEvent(String event) {
    return switch (event) {
      'kpi' => 'kpi',
      'trip.created' || 'trip.updated' => 'trips',
      'driver.status' => 'drivers',
      'alert.created' || 'alert.acknowledged' => 'alerts',
      _ => null,
    };
  }

  /// Best-effort JSON decode of event data.
  static Map<String, dynamic>? decodeJsonMap(String raw) {
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
    } catch (_) {
      return null;
    }
    return null;
  }
}
