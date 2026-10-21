import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'ws_transport.dart';

/// Browser WebSocket via package:web. Token must be in the URL query.
class PlatformWebSocketTransport implements WebSocketTransport {
  web.WebSocket? _socket;
  final _messages = StreamController<String>.broadcast();
  final _closes = StreamController<int>.broadcast();
  final List<({String name, web.EventListener listener})> _handlers = [];

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Stream<int> get closeCodes => _closes.stream;

  @override
  bool get isOpen {
    final socket = _socket;
    return socket != null && socket.readyState == web.WebSocket.OPEN;
  }

  @override
  Future<void> connect(Uri uri) async {
    await close();
    final socket = web.WebSocket(uri.toString());
    _socket = socket;

    final opened = Completer<void>();

    void onOpen(web.Event _) {
      if (!opened.isCompleted) {
        opened.complete();
      }
    }

    void onMessage(web.Event raw) {
      if (_messages.isClosed) {
        return;
      }
      final event = raw as web.MessageEvent;
      final data = event.data;
      if (data == null) {
        return;
      }
      if (data.isA<JSString>()) {
        _messages.add((data as JSString).toDart);
      } else {
        final decoded = data.dartify();
        if (decoded != null) {
          _messages.add(decoded.toString());
        }
      }
    }

    void onClose(web.Event raw) {
      final event = raw as web.CloseEvent;
      if (!_closes.isClosed) {
        _closes.add(event.code);
      }
      if (!opened.isCompleted) {
        opened.completeError(
          StateError('WebSocket closed before open (${event.code})'),
        );
      }
    }

    void onError(web.Event _) {
      if (!opened.isCompleted) {
        opened.completeError(StateError('WebSocket connection error'));
      }
    }

    void add(String name, void Function(web.Event) handler) {
      final listener = handler.toJS;
      _handlers.add((name: name, listener: listener));
      socket.addEventListener(name, listener);
    }

    add('open', onOpen);
    add('message', onMessage);
    add('close', onClose);
    add('error', onError);

    await opened.future;
  }

  @override
  void send(String data) {
    final socket = _socket;
    if (socket == null || socket.readyState != web.WebSocket.OPEN) {
      return;
    }
    socket.send(data.toJS);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    final socket = _socket;
    if (socket != null) {
      for (final handler in _handlers) {
        socket.removeEventListener(handler.name, handler.listener);
      }
      try {
        if (code != null) {
          socket.close(code, reason ?? '');
        } else {
          socket.close();
        }
      } catch (_) {
        // Already closed.
      }
    }
    _handlers.clear();
    _socket = null;
  }
}
