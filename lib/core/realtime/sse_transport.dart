import 'sse_event.dart';

/// Opens a Server-Sent Events connection to [uri].
///
/// Browser `EventSource` cannot set `Authorization` headers — callers must put
/// the session token in the query string per `/docs/realtime`.
abstract class SseTransport {
  Stream<SseEvent> connect(Uri uri);

  Future<void> close();
}
