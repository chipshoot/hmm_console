import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/note_delete_policy.dart';

void main() {
  final note = HmmNote(
    id: 1,
    uuid: 'u',
    subject: 's',
    authorId: 1,
    createDate: DateTime(2026),
  );

  test('ordinary notes can be deleted from Notes', () {
    expect(canDeleteFromNotes(note, 'General'), isTrue);
    expect(
      canDeleteFromNotes(note, null),
      isTrue,
      reason: 'legacy row with no catalog',
    );
    expect(managePlaceFor('General'), isNull);
    expect(managePlaceFor(null), isNull);
  });

  test('entity notes cannot (G7)', () {
    for (final name in [
      'Hmm.ContactMan.Contact',
      'Hmm.CheatsheetMan.Cheatsheet',
      'Hmm.AutomobileMan.GasLog',
      'Hmm.AutomobileMan.AutomobileInfo',
      'Hmm.AutomobileMan.ServiceRecord',
      'Hmm.AutomobileMan.AutoInsurancePolicy',
      'Hmm.AutomobileMan.AutoScheduledService',
      'Hmm.AutomobileMan.GasStation',
      'Hmm.AutomobileMan.DriverLicence',
      'Hmm.System.Subsystem',
      'Hmm.FutureMan.SomethingNew',
    ]) {
      expect(canDeleteFromNotes(note, name), isFalse, reason: name);
    }
  });

  test('each entity note says where it is managed', () {
    expect(managePlaceFor('Hmm.ContactMan.Contact'), NoteManagePlace.contacts);
    expect(
      managePlaceFor('Hmm.CheatsheetMan.Cheatsheet'),
      NoteManagePlace.cheatsheets,
    );
    expect(
      managePlaceFor('Hmm.AutomobileMan.GasLog'),
      NoteManagePlace.automobile,
    );
    expect(
      managePlaceFor('Hmm.AutomobileMan.DriverLicence'),
      NoteManagePlace.automobile,
    );
    expect(managePlaceFor('Hmm.System.Subsystem'), NoteManagePlace.ownScreen);
    expect(
      managePlaceFor('Hmm.FutureMan.SomethingNew'),
      NoteManagePlace.ownScreen,
    );
  });
}
