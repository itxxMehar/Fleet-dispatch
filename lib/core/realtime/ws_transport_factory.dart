import 'ws_transport.dart';
import 'ws_transport_stub.dart'
    if (dart.library.js_interop) 'ws_transport_web.dart';

WebSocketTransport createPlatformWebSocketTransport() =>
    PlatformWebSocketTransport();
