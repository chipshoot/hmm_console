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
  NoteTextIndex slowBuild(HmmNote n) {
    final sw = Stopwatch()..start();
    while (sw.elapsedMicroseconds < 1000) {}
    return _build(n);
  }

  test(
    'warmer fills the cache in time slices, yielding between them',
    () async {
      final cache = NoteTextIndexCache();
      final w = NoteIndexWarmer(
        cache: cache,
        keyOf: _key,
        build: slowBuild,
        sliceBudget: const Duration(milliseconds: 3),
      );
      var done = false;
      final warming = w
          .warm([for (var i = 1; i <= 30; i++) _n(i)])
          .then((_) => done = true);
      var turns = 0;
      while (!done) {
        turns++;
        await Future<void>.delayed(Duration.zero);
      }
      await warming;
      expect(cache.length, 30);
      // 30 ms of work in 3 ms slices: the event loop ran between slices.
      expect(turns, greaterThanOrEqualTo(5));
    },
  );

  test(
    'progress is reported at most every reportEvery, and at the end',
    () async {
      final cache = NoteTextIndexCache();
      var reports = 0;
      final w = NoteIndexWarmer(
        cache: cache,
        keyOf: _key,
        build: slowBuild,
        sliceBudget: const Duration(milliseconds: 2),
        reportEvery: const Duration(hours: 1),
        onProgress: () => reports++,
      );
      await w.warm([for (var i = 1; i <= 20; i++) _n(i)]);
      expect(reports, 1);
      await w.warm([for (var i = 1; i <= 20; i++) _n(i)]); // nothing new
      expect(reports, 1);
    },
  );

  test('a zero reportEvery reports every slice', () async {
    var reports = 0;
    final w = NoteIndexWarmer(
      cache: NoteTextIndexCache(),
      keyOf: _key,
      build: _build,
      sliceBudget: Duration.zero,
      reportEvery: Duration.zero,
      onProgress: () => reports++,
    );
    await w.warm([for (var i = 1; i <= 4; i++) _n(i)]);
    expect(reports, 4);
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
      sliceBudget: Duration.zero,
    );
    final first = w.warm([for (var i = 1; i <= 100; i++) _n(i)]);
    await w.warm([_n(500)]);
    await first;
    expect(cache.length, 1);
  });
}
