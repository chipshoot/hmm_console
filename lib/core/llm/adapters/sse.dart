import 'dart:async';
import 'dart:convert';

/// One server-sent event: optional `event:` name and the joined `data:` lines.
class SseEvent {
  const SseEvent({this.event, required this.data});

  final String? event;
  final String data;

  @override
  bool operator ==(Object other) =>
      other is SseEvent && other.event == event && other.data == data;

  @override
  int get hashCode => Object.hash(event, data);

  @override
  String toString() => 'SseEvent(event: $event, data: ${data.length} chars)';
}

/// Parses an SSE byte stream. UTF-8 is decoded across chunk boundaries; events
/// end at a blank line; a trailing event without one is emitted at stream end.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  String? event;
  final data = <String>[];

  SseEvent? flush() {
    if (data.isEmpty && event == null) return null;
    final e = SseEvent(event: event, data: data.join('\n'));
    event = null;
    data.clear();
    return e;
  }

  final lines = bytes
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) {
      final e = flush();
      if (e != null) yield e;
    } else if (line.startsWith(':')) {
      continue;
    } else {
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') {
        event = value;
      } else if (field == 'data') {
        data.add(value);
      }
    }
  }
  final e = flush();
  if (e != null) yield e;
}
