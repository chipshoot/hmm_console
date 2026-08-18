import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/features/cheatsheet/domain/source_scope.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';

HmmNote note(int id, {required String subject, int? catalogId}) => HmmNote(
      id: id,
      uuid: 'uuid-$id',
      subject: subject,
      authorId: 1,
      createDate: DateTime(2026),
      catalogId: catalogId,
    );

/// Catalog ids as the app really lays them out: several automobile catalogs,
/// a General one, plus the two infrastructure catalogs.
const catalogNames = <int, String>{
  1: 'Hmm.AutomobileMan.AutomobileInfo',
  2: 'Hmm.AutomobileMan.AutoInsurancePolicy',
  3: 'Hmm.AutomobileMan.ServiceRecord',
  4: 'General',
  5: 'Hmm.CheatsheetMan.Cheatsheet',
  6: 'Hmm.System.Subsystem',
};

final car = note(1, subject: 'My Car', catalogId: 1);
final policy = note(2, subject: 'State Farm 4471', catalogId: 2);
final contact = note(3, subject: "Dad's contact info", catalogId: 4);
final card = note(4, subject: 'Cheatsheet:abc-123', catalogId: 5);
final anchor = note(5, subject: 'Automobile', catalogId: 6);

List<String> subjects(List<HmmNote> notes) =>
    notes.map((n) => n.subject).toList();

void main() {
  group('infrastructure notes are never sources', () {
    // These are the app's own bookkeeping. A cheatsheet card is itself stored
    // as a note, so without this the picker offers you every card you have
    // ever saved as something to reference — and the list grows each time you
    // save one.
    test('a cheatsheet card is not offered, in either group', () {
      final scoped = scopeSourceNotes(
        all: [car, card, contact],
        catalogNames: catalogNames,
        domain: sourceDomainFor('accidentClaim'),
      );

      expect(subjects(scoped.preferred), isNot(contains('Cheatsheet:abc-123')));
      expect(subjects(scoped.other), isNot(contains('Cheatsheet:abc-123')));
    });

    test('a subsystem anchor is not offered', () {
      final scoped = scopeSourceNotes(
        all: [car, anchor],
        catalogNames: catalogNames,
        domain: sourceDomainFor('accidentClaim'),
      );

      expect(subjects(scoped.preferred), isNot(contains('Automobile')));
      expect(subjects(scoped.other), isNot(contains('Automobile')));
    });

    test('they are dropped even when the template has no domain', () {
      // Asserted separately: the no-domain path sends everything to `other`,
      // and an implementation that filtered only while partitioning by domain
      // would leak infrastructure notes here while passing the tests above.
      final scoped = scopeSourceNotes(
        all: [contact, card, anchor],
        catalogNames: catalogNames,
        domain: sourceDomainFor('blank'),
      );

      expect(subjects(scoped.other), ["Dad's contact info"]);
      expect(scoped.preferred, isEmpty);
    });
  });

  group('domain ranking', () {
    test('an accident claim puts every automobile catalog first', () {
      final scoped = scopeSourceNotes(
        all: [contact, car, policy],
        catalogNames: catalogNames,
        domain: sourceDomainFor('accidentClaim'),
      );

      // The whole point: all three AutomobileMan catalogs count as the
      // vehicle domain, not just AutomobileInfo.
      expect(subjects(scoped.preferred), ['My Car', 'State Farm 4471']);
      expect(subjects(scoped.other), ["Dad's contact info"]);
    });

    test('nothing is excluded — cross-domain rows stay bindable', () {
      // The Accident Claim template asks for Driver, Phone and Address, which
      // live in a General note. A hard filter to the vehicle domain would make
      // three of its seven rows impossible to fill.
      final scoped = scopeSourceNotes(
        all: [car, contact],
        catalogNames: catalogNames,
        domain: sourceDomainFor('accidentClaim'),
      );

      expect(
        subjects([...scoped.preferred, ...scoped.other]),
        containsAll(['My Car', "Dad's contact info"]),
      );
    });

    test('a template with no domain leaves everything in one group', () {
      final scoped = scopeSourceNotes(
        all: [car, contact],
        catalogNames: catalogNames,
        domain: sourceDomainFor('blank'),
      );

      expect(scoped.preferred, isEmpty);
      expect(subjects(scoped.other), ['My Car', "Dad's contact info"]);
    });

    test('input order is preserved within each group', () {
      // The repository already sorts by last-modified; scoping must not
      // silently reshuffle that.
      final a = note(10, subject: 'Car A', catalogId: 1);
      final b = note(11, subject: 'Car B', catalogId: 1);
      final scoped = scopeSourceNotes(
        all: [b, a],
        catalogNames: catalogNames,
        domain: sourceDomainFor('accidentClaim'),
      );

      expect(subjects(scoped.preferred), ['Car B', 'Car A']);
    });
  });

  group('unknown catalogs', () {
    test('a note with no catalog is kept, in the other group', () {
      // Dropping it would make the note unbindable, which is the failure this
      // whole change exists to avoid. Unknown means "not ranked", not "hidden".
      final orphan = note(9, subject: 'Loose Note');
      final scoped = scopeSourceNotes(
        all: [orphan],
        catalogNames: catalogNames,
        domain: sourceDomainFor('accidentClaim'),
      );

      expect(subjects(scoped.other), ['Loose Note']);
    });

    test('a catalog id missing from the map is kept, in the other group', () {
      final unknown = note(8, subject: 'From The Future', catalogId: 99);
      final scoped = scopeSourceNotes(
        all: [unknown],
        catalogNames: catalogNames,
        domain: sourceDomainFor('accidentClaim'),
      );

      expect(subjects(scoped.other), ['From The Future']);
    });
  });

  group('sourceDomainFor', () {
    test('the accident claim template is the vehicle domain', () {
      final domain = sourceDomainFor('accidentClaim');
      expect(domain, isNotNull);
      // The id, not a heading: display copy lives in SourcePicker, so this
      // layer carries no English and stays translatable without touching it.
      expect(domain!.id, SourceDomainId.vehicle);
      expect(domain.catalogPrefix, 'Hmm.AutomobileMan.');
    });

    test('templates with no matching catalogs have no domain', () {
      // healthInfo and document describe notes this app does not yet model as
      // their own catalogs; claiming a domain for them would rank nothing and
      // add a heading over an empty group.
      expect(sourceDomainFor('healthInfo'), isNull);
      expect(sourceDomainFor('document'), isNull);
      expect(sourceDomainFor('blank'), isNull);
    });

    test('an unrecognised template id has no domain', () {
      expect(sourceDomainFor('nope'), isNull);
    });
  });

  group('the copied catalog names have not drifted', () {
    // source_scope.dart repeats these names rather than importing them, so it
    // stays free of Drift and Riverpod. That copy is only safe while something
    // checks it: rename a catalog at its definition and the picker would go on
    // matching the old string, silently offering cheatsheet cards as sources
    // again with every other test still green.
    test('the cheatsheet catalog name matches its definition', () {
      expect(kInfrastructureCatalogNames, contains(cheatsheetCatalogName));
    });

    test('the subsystem anchor catalog name matches its definition', () {
      expect(kInfrastructureCatalogNames, contains(kSubsystemAnchorCatalogName));
    });

    test('nothing else has crept into the infrastructure set', () {
      // Guards the other direction: an extra name here silently hides a whole
      // catalog of real notes from the picker.
      expect(kInfrastructureCatalogNames, hasLength(2));
    });
  });
}
