import 'sse_transport.dart';
import 'sse_transport_stub.dart'
    if (dart.library.js_interop) 'sse_transport_web.dart'
    as impl;

SseTransport createPlatformSseTransport() => impl.PlatformSseTransport();
