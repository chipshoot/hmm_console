import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/query/markdown_text.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_query_engine.dart';
import 'package:hmm_console/features/notes/query/note_text_index.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _Pinyin implements PinyinTranscriber {
  @override
  List<String> given(String text) => [for (final r in text.runes) 'p${r % 7}'];
  @override
  List<String> family(String text) => given(text);
}

const _n = 5000;

NotesListData _corpus() {
  final notes = <HmmNote>[];
  final tags = <int, List<NoteTagLabel>>{};
  final states = <String, NoteState>{};
  for (var i = 1; i <= _n; i++) {
    final han = i % 10 == 0;
    final body = StringBuffer();
    while (body.length < 300) {
      body.write(
        han
            ? '**今天** 换机油 oil change $i 保养 记录 [link](http://x/$i) '
            : '**Did** an oil change ${i % 3} at the shop, [link](http://x/$i) '
                  'plus filter and wiper notes for car $i. ',
      );
    }
    final n = HmmNote(
      id: i,
      uuid: 'u$i',
      subject: han ? '换机油 $i' : 'Oil change $i',
      authorId: 1,
      createDate: DateTime(2026, 1, 1).add(Duration(hours: i)),
      content: body.toString(),
    );
    notes.add(n);
    tags[i] = [(id: i % 20, name: 'tag${i % 20}')];
    if (i % 25 == 0) {
      states[n.uuid] = NoteState(
        noteUuid: n.uuid,
        isPinned: i % 50 == 0,
        flagColor: i % 7,
        lastModifiedDate: DateTime(2026),
      );
    }
  }
  return NotesListData(
    all: notes,
    catalogsById: const {},
    tagsByNoteId: tags,
    statesByUuid: states,
  );
}

void main() {
  test('5,000 notes evaluate in <= 50 ms with a warm index', () {
    final corpus = _corpus();
    final pinyin = _Pinyin();
    final cache = NoteTextIndexCache();
    final keys = <int, NoteTextKey>{};
    NoteTextKey keyOf(HmmNote n) => keys[n.id] ??= (
      noteId: n.id,
      version: '',
      locale: 'en',
      parentTitle: '',
      tags: (corpus.tagsByNoteId[n.id] ?? const []).map((t) => t.name).join(),
    );
    for (final n in corpus.all) {
      cache.store(
        keyOf(n),
        buildNoteTextIndex(
          title: n.subject,
          body: markdownToPlainText(n.content ?? ''),
          tagNames: [for (final t in corpus.tagsByNoteId[n.id]!) t.name],
          pinyin: pinyin,
        ),
      );
    }
    final engine = InMemoryNoteQueryEngine(
      cache: cache,
      keyOf: keyOf,
      titleOf: (n) => n.subject,
      pinyin: pinyin,
    );
    final now = DateTime(2026, 9, 1);
    NoteQuery q(String t) => NoteQuery(text: t);

    engine.evaluate(q('oil'), corpus, now: now, firstDayOfWeek: 1); // JIT
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      engine.evaluate(
        q('oil change ${i % 3}'),
        corpus,
        now: now,
        firstDayOfWeek: 1,
      );
    }
    final perCall = sw.elapsedMilliseconds / 10;
    expect(perCall, lessThanOrEqualTo(50));
  });
}
