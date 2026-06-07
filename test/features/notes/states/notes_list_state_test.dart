import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

HmmNote _n(int id, String subject, int catalogId, DateTime created,
        {DateTime? modified}) =>
    HmmNote(
      id: id, uuid: 'u$id', subject: subject, authorId: 1,
      catalogId: catalogId, createDate: created, lastModifiedDate: modified,
    );

void main() {
  final notes = [
    _n(1, 'Banana', 10, DateTime(2026, 1, 1)),
    _n(2, 'apple', 20, DateTime(2026, 1, 3)),
    _n(3, 'Cherry', 10, DateTime(2026, 1, 2)),
  ];
  NotesListData data() => NotesListData(all: notes, catalogsById: const {});

  test('default sort is newest-first by createDate', () {
    expect(data().visible.map((n) => n.id).toList(), [2, 3, 1]);
  });

  test('subjectAZ sorts case-insensitively', () {
    final v = data().copyWith(sort: NoteSort.subjectAZ).visible;
    expect(v.map((n) => n.subject).toList(), ['apple', 'Banana', 'Cherry']);
  });

  test('catalog filter restricts to selected catalogs', () {
    final v = data().copyWith(catalogFilter: {10}).visible;
    expect(v.map((n) => n.id).toList()..sort(), [1, 3]);
  });

  test('query matches subject substring, case-insensitive', () {
    final v = data().copyWith(query: 'an').visible; // "Banana"
    expect(v.map((n) => n.id).toList(), [1]);
  });

  test('countsByCatalog tallies per catalog', () {
    expect(data().countsByCatalog, {10: 2, 20: 1});
  });

  test('copyWith can clear the filter back to all', () {
    final filtered = data().copyWith(catalogFilter: {10});
    expect(filtered.copyWith(catalogFilter: null).catalogFilter, isNull);
  });
}
