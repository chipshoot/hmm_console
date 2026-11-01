import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/query/note_index_warmer.dart';
import 'package:hmm_console/features/notes/query/note_text_index.dart';

class _Pinyin implements PinyinTranscriber {
  @override
  List<String> given(String text) => [text];
  @override
  List<String> family(String text) => [text];
}

HmmNote _n(int id) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: 's$id',
  authorId: 1,
  createDate: DateTime(2026, 1, 1),
);

NoteTextKey _key(HmmNote n) =>
    (noteId: n.id, version: 'v', locale: 'en', parentTitle: '', tags: '');

NoteTextIndex _build(HmmNote n) => buildNoteTextIndex(
  title: n.subject,
  body: 'body ${n.id}',
  pinyin: _Pinyin(),
);

void main() {
  test('warmer fills the cache in chunks and reports each chunk', () async {
    final cache = NoteTextIndexCache();
    var chunks = 0;
    final w = NoteIndexWarmer(
      cache: cache,
      keyOf: _key,
      build: _build,
      onChunk: () => chunks++,
    );
    await w.warm([for (var i = 1; i <= 450; i++) _n(i)]);
    expect(chunks, 3);
    expect(cache.length, 450);
  });

  test('retains only live ids and skips already indexed notes', () async {
    final cache = NoteTextIndexCache();
    var builds = 0;
    final w = NoteIndexWarmer(
      cache: cache,
      keyOf: _key,
      build: (n) {
        builds++;
        return _build(n);
      },
    );
    await w.warm([_n(1), _n(2)]);
    await w.warm([_n(2), _n(3)]);
    expect(builds, 3);
    expect(cache.length, 2);
    expect(cache.lookup(_key(_n(1))), isNull);
  });

  test(
    'a note whose build throws stays unindexed and is logged once',
    () async {
      final cache = NoteTextIndexCache();
      final logs = <String?>[];
      final old = debugPrint;
      debugPrint = (m, {wrapWidth}) => logs.add(m);
      addTearDown(() => debugPrint = old);
      final w = NoteIndexWarmer(
        cache: cache,
        keyOf: _key,
        build: (n) =>
            n.id.isOdd ? throw StateError('secret ${n.id}') : _build(n),
      );
      await w.warm([for (var i = 1; i <= 6; i++) _n(i)]);
      expect(cache.length, 3);
      expect(cache.lookup(_key(_n(1))), isNull);
      expect(logs, ['NoteIndexWarmer: index failed (StateError)']);
    },
  );

  test('a newer warm cancels the previous one', () async {
    final cache = NoteTextIndexCache();
    final w = NoteIndexWarmer(
      cache: cache,
      keyOf: _key,
      build: _build,
      chunkSize: 10,
    );
    final first = w.warm([for (var i = 1; i <= 100; i++) _n(i)]);
    await w.warm([_n(500)]);
    await first;
    expect(cache.length, 1);
  });
}
