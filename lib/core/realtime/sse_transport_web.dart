import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'sse_event.dart';
import 'sse_transport.dart';

/// Browser EventSource via package:web (token must be in the URL query).
class PlatformSseTransport implements SseTransport {
  web.EventSource? _source;
  StreamController<SseEvent>? _controller;
  final List<({String name, web.EventListener listener})> _handlers = [];

  static const _namedEvents = <String>[
    'ready',
    'kpi',
    'trip.created',
    'trip.updated',
    'driver.status',
    'alert.created',
    'alert.acknowledged',
    'ping',
  ];

  @override
  Stream<SseEvent> connect(Uri uri) {
    close();
    final controller = StreamController<SseEvent>.broadcast();
    _controller = controller;

    final source = web.EventSource(uri.toString());
    _source = source;

    for (final name in _namedEvents) {
      void onEvent(web.Event raw) {
        if (controller.isClosed) {
          return;
        }
        final message = raw as web.MessageEvent;
        controller.add(
          SseEvent(
            id: message.lastEventId.isEmpty ? null : message.lastEventId,
            event: name,
            data: _stringifyData(message.data),
          ),
        );
      }

      final listener = onEvent.toJS;
      _handlers.add((name: name, listener: listener));
      source.addEventListener(name, listener);
    }

    void onError(web.Event _) {
      if (!controller.isClosed) {
        controller.addError(StateError('SSE connection error'));
      }
    }

    final errorListener = onError.toJS;
    _handlers.add((name: 'error', listener: errorListener));
    source.addEventListener('error', errorListener);

    return controller.stream;
  }

  @override
  Future<void> close() async {
    final source = _source;
    if (source != null) {
      for (final handler in _handlers) {
        source.removeEventListener(handler.name, handler.listener);
      }
      source.close();
    }
    _handlers.clear();
    _source = null;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  static String _stringifyData(JSAny? data) {
    if (data == null) {
      return '';
    }
    if (data.isA<JSString>()) {
      return (data as JSString).toDart;
    }
    final decoded = data.dartify();
    return decoded?.toString() ?? '';
  }
}
