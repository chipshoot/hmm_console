import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/adapters/sse.dart';

Stream<List<int>> chunks(List<List<int>> parts) => Stream.fromIterable(parts);
Stream<List<int>> text(String s) => chunks([utf8.encode(s)]);

void main() {
  test('split chunks reassemble', () async {
    final bytes = utf8.encode('data: 你好 中文\n\n');
    final i = bytes.indexOf(0xE4); // first byte of 中
    final parts = [
      bytes.sublist(0, 3),
      bytes.sublist(3, i + 1), // cuts inside 中
      bytes.sublist(i + 1),
    ];
    final events = await parseSse(chunks(parts)).toList();
    expect(events, [const SseEvent(data: '你好 中文')]);
  });

  test('multi-line data joins with newline', () async {
    final events = await parseSse(text('data: a\ndata: b\n\n')).toList();
    expect(events, [const SseEvent(data: 'a\nb')]);
  });

  test('comment keep-alives ignored', () async {
    final events = await parseSse(
      text(': ping\n\ndata: x\n: ping\n\n'),
    ).toList();
    expect(events, [const SseEvent(data: 'x')]);
  });

  test('named events', () async {
    final events = await parseSse(
      text('event: content_block_delta\ndata: {"a":1}\n\n'),
    ).toList();
    expect(events, [
      const SseEvent(event: 'content_block_delta', data: '{"a":1}'),
    ]);
  });

  test('[DONE] passes through as data', () async {
    final events = await parseSse(text('data: [DONE]\n\n')).toList();
    expect(events, [const SseEvent(data: '[DONE]')]);
  });

  test('last event without blank line emitted', () async {
    final events = await parseSse(text('data: 1\n\ndata: 2')).toList();
    expect(events, [const SseEvent(data: '1'), const SseEvent(data: '2')]);
  });

  test('source error forwarded', () async {
    final src = Stream<List<int>>.multi((c) {
      c.add(utf8.encode('data: 1\n\n'));
      c.addError(StateError('boom'));
      c.close();
    });
    await expectLater(
      parseSse(src),
      emitsInOrder([const SseEvent(data: '1'), emitsError(isA<StateError>())]),
    );
  });
}
