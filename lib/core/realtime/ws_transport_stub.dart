import 'dart:async';

import 'ws_transport.dart';

/// Non-web placeholder — map live updates need the browser transport.
class PlatformWebSocketTransport implements WebSocketTransport {
  final _messages = StreamController<String>.broadcast();
  final _closes = StreamController<int>.broadcast();
  bool _open = false;

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Stream<int> get closeCodes => _closes.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> connect(Uri uri) async {
    _open = true;
  }

  @override
  void send(String data) {}

  @override
  Future<void> close([int? code, String? reason]) async {
    _open = false;
    if (code != null && !_closes.isClosed) {
      _closes.add(code);
    }
  }
}
