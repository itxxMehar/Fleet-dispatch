import 'dart:async';

/// Minimal WebSocket transport abstraction (browser vs stub).
abstract class WebSocketTransport {
  Stream<String> get messages;
  Stream<int> get closeCodes;
  bool get isOpen;

  Future<void> connect(Uri uri);
  void send(String data);
  Future<void> close([int? code, String? reason]);
}
