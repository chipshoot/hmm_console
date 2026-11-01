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

  // Ported to the query engine in Task 4 (git history has the bodies).
  for (final name in [
    'default sort is newest-first by createDate',
    'subjectAZ sorts case-insensitively',
    'catalog filter restricts to selected catalogs',
    'query matches subject substring, case-insensitive',
  ]) {
    test(name, () {}, skip: 'ported to the engine in Task 4');
  }

  test('countsByCatalog tallies per catalog', () {
    expect(data().countsByCatalog, {10: 2, 20: 1});
  });
}
