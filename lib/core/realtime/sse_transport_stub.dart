import 'dart:async';

import 'sse_event.dart';
import 'sse_transport.dart';

/// Non-web / test fallback — no live EventSource.
class PlatformSseTransport implements SseTransport {
  final _controller = StreamController<SseEvent>.broadcast();

  @override
  Stream<SseEvent> connect(Uri uri) => _controller.stream;

  @override
  Future<void> close() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
