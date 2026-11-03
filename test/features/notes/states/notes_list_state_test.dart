import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_query_engine.dart';
import 'package:hmm_console/features/notes/query/note_text_index.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

HmmNote _n(
  int id,
  String subject,
  int catalogId,
  DateTime created, {
  DateTime? modified,
}) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
  authorId: 1,
  catalogId: catalogId,
  createDate: created,
  lastModifiedDate: modified,
);

List<HmmNote> _evaluate(NotesListData d) {
  final engine = InMemoryNoteQueryEngine(
    cache: NoteTextIndexCache(),
    keyOf: (n) =>
        (noteId: n.id, version: '', locale: '', parentTitle: '', tags: ''),
    titleOf: (n) => n.subject,
    pinyin: _NoPinyin(),
  );
  return [
    for (final g
        in engine
            .evaluate(d.query, d, now: DateTime(2026, 6, 1), firstDayOfWeek: 1)
            .groups)
      for (final h in g.hits) h.note,
  ];
}

class _NoPinyin implements PinyinTranscriber {
  @override
  List<String> given(String text) => [text];
  @override
  List<String> family(String text) => [text];
}

void main() {
  final notes = [
    _n(1, 'Banana', 10, DateTime(2026, 1, 1)),
    _n(2, 'apple', 20, DateTime(2026, 1, 3)),
    _n(3, 'Cherry', 10, DateTime(2026, 1, 2)),
  ];
  NotesListData data([NoteQuery q = const NoteQuery.initial()]) =>
      NotesListData(
        all: notes,
        catalogsById: const {},
        query: q,
        catalogDomainById: const {10: 'A', 20: 'B'},
      );

  test('default sort is newest-first by createDate', () {
    expect(_evaluate(data()).map((n) => n.id).toList(), [2, 3, 1]);
  });

  test('subjectAZ sorts case-insensitively', () {
    final v = _evaluate(data(const NoteQuery(sort: NoteSort.subjectAZ)));
    expect(v.map((n) => n.subject).toList(), ['apple', 'Banana', 'Cherry']);
  });

  test('catalog filter restricts to selected catalogs', () {
    final v = _evaluate(data(NoteQuery(source: const DomainSource(key: 'A'))));
    expect(v.map((n) => n.id).toList()..sort(), [1, 3]);
  });

  test('query matches subject substring, case-insensitive', () {
    final v = _evaluate(data(const NoteQuery(text: 'an'))); // "Banana"
    expect(v.map((n) => n.id).toList(), [1]);
  });

  test('countsByCatalog tallies per catalog', () {
    expect(data().countsByCatalog, {10: 2, 20: 1});
  });
}
