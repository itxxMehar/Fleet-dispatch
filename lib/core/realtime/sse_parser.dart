import 'sse_event.dart';

/// Parses `text/event-stream` chunks into [SseEvent]s.
class SseParser {
  final StringBuffer _buffer = StringBuffer();
  String? _id;
  String _event = 'message';
  final StringBuffer _data = StringBuffer();

  /// Feed decoded text; returns completed events (blank-line terminated).
  List<SseEvent> addChunk(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();
    final parts = text.split('\n');
    _buffer
      ..clear()
      ..write(parts.isEmpty ? '' : parts.removeLast());

    final events = <SseEvent>[];
    for (final rawLine in parts) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      if (line.isEmpty) {
        final data = _data.toString();
        if (data.isNotEmpty || _event != 'message' || _id != null) {
          events.add(
            SseEvent(
              id: _id,
              event: _event,
              data: data.endsWith('\n')
                  ? data.substring(0, data.length - 1)
                  : data,
            ),
          );
        }
        _id = null;
        _event = 'message';
        _data.clear();
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }
      final colon = line.indexOf(':');
      final field = colon == -1 ? line : line.substring(0, colon);
      var value = colon == -1 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
      switch (field) {
        case 'id':
          _id = value;
        case 'event':
          _event = value;
        case 'data':
          if (_data.isNotEmpty) {
            _data.write('\n');
          }
          _data.write(value);
      }
    }
    return events;
  }
}
