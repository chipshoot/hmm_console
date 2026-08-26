// Embedded contact blocks must survive a policy save.
//
// Both createPolicy and updatePolicy rebuild the policy field by field, so a
// field they forget to copy is discarded before serialization ever sees it -
// silently, with no error and nothing on screen to explain it. These tests
// exercise the real repository against a real database rather than the codec
// alone, because the codec was never the part at risk.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/contact_block/contact_info.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_insurance_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/auto_insurance_policy.dart';

void main() {
  late HmmDatabase db;
  late LocalInsuranceRepository repo;

  const agent = ContactInfo(
    role: ContactRoles.agent,
    name: 'Ada Lovelace',
    phone: '555-0100',
    email: 'ada@example.com',
  );

  AutoInsurancePolicy policy({List<ContactInfo> contacts = const []}) =>
      AutoInsurancePolicy(
        id: 0,
        automobileId: 1,
        provider: 'Intact',
        policyNumber: 'POL-1',
        effectiveDate: DateTime.utc(2026, 1, 1),
        expiryDate: DateTime.utc(2027, 1, 1),
        premium: 1200,
        contacts: contacts,
      );

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'insurance-contacts-tester'),
        );
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();

    repo = LocalInsuranceRepository(
      LocalHmmNoteRepository(db, () async => author),
      LocalNoteCatalogRepository(db),
    );
  });

  tearDown(() async => db.close());

  test('an agent survives a create and reads back whole', () async {
    final created = await repo.createPolicy(1, policy(contacts: [agent]));

    expect(created.contacts, hasLength(1));
    expect(created.contacts.single.name, 'Ada Lovelace');
    expect(created.contacts.single.phone, '555-0100');
    expect(created.contacts.single.role, ContactRoles.agent);
  });

  test('an agent survives an edit that has nothing to do with it', () async {
    final created = await repo.createPolicy(1, policy(contacts: [agent]));

    await repo.updatePolicy(
      1,
      created.id,
      AutoInsurancePolicy(
        id: created.id,
        automobileId: 1,
        provider: 'Intact',
        policyNumber: 'POL-1-RENEWED',
        effectiveDate: created.effectiveDate,
        expiryDate: created.expiryDate,
        premium: 1300,
        contacts: created.contacts,
      ),
    );

    final reloaded = await repo.getPolicyById(1, created.id);
    expect(reloaded.policyNumber, 'POL-1-RENEWED');
    expect(reloaded.contacts.single.phone, '555-0100');
  });

  test('a policy may carry more than one block', () async {
    final created = await repo.createPolicy(
      1,
      policy(contacts: [
        agent,
        const ContactInfo(role: 'emergency', name: 'Claims line', phone: '555-9999'),
      ]),
    );

    expect(created.contacts, hasLength(2));
    expect(created.contacts.last.role, 'emergency');
  });

  test('a policy with no contacts reads back empty, not null', () async {
    final created = await repo.createPolicy(1, policy());
    expect(created.contacts, isEmpty);
  });

  test('an unknown role round-trips untouched', () async {
    final created = await repo.createPolicy(
      1,
      policy(contacts: [const ContactInfo(role: 'veterinarian', phone: '1')]),
    );
    expect(created.contacts.single.role, 'veterinarian');
  });
}
