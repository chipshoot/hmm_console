// Regression: selecting the "Automobile" domain filter on the notes list must
// also surface General notes attached to the Automobile *subsystem* (via
// parentNoteId), not only notes whose catalog is in the automobile domain.

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

// catalog ids
const _general = 10;
const _gasLog = 20;
// the automobile subsystem anchor note id
const _autoAnchor = 99;

HmmNote _n(int id, {int? catalog, int? parent}) => HmmNote(
      id: id, uuid: 'u$id', subject: 'note $id', authorId: 1,
      createDate: DateTime(2026, 1, id), catalogId: catalog, parentNoteId: parent);

// A General note attached to the automobile subsystem anchor.
final _attached = _n(1, catalog: _general, parent: _autoAnchor);
// A real automobile-catalog note (gas log).
final _gas = _n(2, catalog: _gasLog);
// An unrelated General note (no parent).
final _plain = _n(3, catalog: _general);

NotesListData _data({Set<int>? filter}) => NotesListData(
      all: [_attached, _gas, _plain],
      catalogsById: const {},
      catalogFilter: filter,
      catalogDomainById: const {_general: 'General', _gasLog: 'AutomobileMan'},
      anchorDomainById: const {_autoAnchor: 'AutomobileMan'},
    );

void main() {
  test('Automobile filter includes notes attached to the automobile subsystem',
      () {
    final ids = _data(filter: {_gasLog}).visible.map((n) => n.id).toSet();
    expect(ids.contains(2), isTrue, reason: 'the automobile-catalog note');
    expect(ids.contains(1), isTrue,
        reason: 'the General note attached to the automobile subsystem');
    expect(ids.contains(3), isFalse,
        reason: 'an unrelated General note must not appear');
  });

  test('no filter shows everything', () {
    expect(_data().visible.length, 3);
  });

  test('General filter shows only unattached General notes (attached belong to '
      'their subsystem, not General)', () {
    final ids = _data(filter: {_general}).visible.map((n) => n.id).toSet();
    // note 1 is a General note attached to the automobile subsystem -> it
    // belongs to Automobile, NOT General. Only note 3 (unattached) shows.
    expect(ids, {3});
  });
}
