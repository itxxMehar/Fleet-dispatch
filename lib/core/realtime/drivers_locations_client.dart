import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../auth/token_store.dart';
import '../config/app_config.dart';
import 'ws_transport.dart';
import 'ws_transport_factory.dart';

enum DriversSocketPhase {
  disconnected,
  connecting,
  connected,
  reconnecting,
  unauthorized,
}

/// Shared WebSocket client for the documented `drivers.locations` channel.
///
/// Bounded exponential reconnect. Close code `4001` stops reconnecting
/// (caller should treat as session expiry). Never logs the token.
class DriversLocationsClient {
  DriversLocationsClient({
    required AppConfig config,
    required TokenStore tokenStore,
    WebSocketTransport? transport,
    this.onUnauthorized,
  }) : _config = config,
       _tokens = tokenStore,
       _transport = transport ?? createPlatformWebSocketTransport();

  static const channel = 'drivers.locations';
  static const unauthorizedCloseCode = 4001;

  final AppConfig _config;
  final TokenStore _tokens;
  final WebSocketTransport _transport;

  /// Fired when the socket closes with code 4001. Must not clear session
  /// from transient disconnects — only from this code / server auth error.
  void Function()? onUnauthorized;

  final _frames = StreamController<Map<String, dynamic>>.broadcast();
  final _phaseController = StreamController<DriversSocketPhase>.broadcast();

  StreamSubscription<String>? _messageSub;
  StreamSubscription<int>? _closeSub;
  Timer? _reconnectTimer;
  int _attempt = 0;
  int _commandSeq = 0;
  bool _wantConnection = false;
  bool _subscribed = false;
  bool _intentionalClose = false;
  DriversSocketPhase _phase = DriversSocketPhase.disconnected;

  Stream<Map<String, dynamic>> get frames => _frames.stream;
  Stream<DriversSocketPhase> get phases => _phaseController.stream;
  DriversSocketPhase get phase => _phase;
  bool get isConnected => _phase == DriversSocketPhase.connected;

  /// Starts (or keeps) the connection and ensures `drivers.locations` is subscribed.
  Future<void> ensureSubscribed() async {
    _wantConnection = true;
    if (_phase == DriversSocketPhase.unauthorized) {
      return;
    }
    if (_transport.isOpen) {
      if (!_subscribed) {
        _sendSubscribe();
      }
      return;
    }
    await _connect();
  }

  Future<void> disconnect() async {
    _wantConnection = false;
    _subscribed = false;
    _attempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _intentionalClose = true;
    await _tearDownSocket();
    _setPhase(DriversSocketPhase.disconnected);
  }

  Future<void> _connect() async {
    if (!_wantConnection || _phase == DriversSocketPhase.unauthorized) {
      return;
    }
    final token = _tokens.token;
    if (token == null || token.isEmpty) {
      await disconnect();
      return;
    }

    _reconnectTimer?.cancel();
    _setPhase(
      _attempt == 0
          ? DriversSocketPhase.connecting
          : DriversSocketPhase.reconnecting,
    );

    try {
      await _tearDownSocket(preservePhase: true);
      _intentionalClose = false;
      await _transport.connect(_config.websocketUri(token: token));
      _messageSub = _transport.messages.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
      );
      _closeSub = _transport.closeCodes.listen(_onCloseCode);
      _attempt = 0;
      _setPhase(DriversSocketPhase.connected);
      _sendSubscribe();
    } catch (_) {
      await _scheduleReconnect();
    }
  }

  void _sendSubscribe() {
    if (!_transport.isOpen) {
      return;
    }
    _commandSeq += 1;
    final frame = {
      'type': 'subscribe',
      'id': 'c-$_commandSeq',
      'payload': {'channel': channel},
    };
    _transport.send(jsonEncode(frame));
  }

  void _onMessage(String raw) {
    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) {
        decoded = value;
      } else if (value is Map) {
        decoded = Map<String, dynamic>.from(value);
      }
    } catch (_) {
      return;
    }
    if (decoded == null) {
      return;
    }

    final type = decoded['type'] as String?;
    if (type == 'ack') {
      final payload = decoded['payload'];
      if (payload is Map && payload['subscribed'] == channel) {
        _subscribed = true;
      }
      return;
    }
    if (type == 'error') {
      final payload = decoded['payload'];
      final code = payload is Map ? payload['code'] as String? : null;
      if (code == 'UNAUTHENTICATED') {
        _handleUnauthorized();
        return;
      }
      return;
    }
    if (type == 'welcome' || type == 'pong') {
      return;
    }
    if (!_frames.isClosed) {
      _frames.add(decoded);
    }
  }

  void _onCloseCode(int code) {
    _subscribed = false;
    if (_intentionalClose) {
      return;
    }
    if (code == unauthorizedCloseCode) {
      _handleUnauthorized();
      return;
    }
    unawaited(_scheduleReconnect());
  }

  void _handleUnauthorized() {
    _wantConnection = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscribed = false;
    _setPhase(DriversSocketPhase.unauthorized);
    onUnauthorized?.call();
    unawaited(_tearDownSocket(preservePhase: true));
  }

  Future<void> _scheduleReconnect() async {
    if (!_wantConnection || _phase == DriversSocketPhase.unauthorized) {
      return;
    }
    _subscribed = false;
    _setPhase(DriversSocketPhase.reconnecting);
    _reconnectTimer?.cancel();
    final delayMs = math.min(30000, 1000 * math.pow(2, _attempt).toInt());
    _attempt += 1;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_connect());
    });
  }

  Future<void> _tearDownSocket({bool preservePhase = false}) async {
    await _messageSub?.cancel();
    await _closeSub?.cancel();
    _messageSub = null;
    _closeSub = null;
    await _transport.close();
    if (!preservePhase && _phase != DriversSocketPhase.unauthorized) {
      _setPhase(DriversSocketPhase.disconnected);
    }
  }

  void _setPhase(DriversSocketPhase next) {
    if (_phase == next) {
      return;
    }
    _phase = next;
    if (!_phaseController.isClosed) {
      _phaseController.add(next);
    }
  }
}
