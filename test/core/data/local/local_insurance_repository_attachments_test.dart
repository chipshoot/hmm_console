// Attachments on an insurance policy must survive a save.
//
// They are a read-through projection of the OWNING NOTE's attachments column,
// not part of the policy JSON, so they travel a different path from every
// other field and can be dropped independently of them. createPolicy and
// updatePolicy also rebuild the policy field by field, which is a second way
// to lose them silently.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_insurance_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/auto_insurance_policy.dart';

const _card = VaultRef(
    path: 'attachments/note-1/card.jpg',
    contentType: 'image/jpeg',
    byteSize: 1000,
    originalName: 'insurance-card.jpg');
const _policyPdf = VaultRef(
    path: 'attachments/note-1/policy.pdf',
    contentType: 'application/pdf',
    byteSize: 2000,
    originalName: 'policy.pdf');

void main() {
  late HmmDatabase db;
  late LocalInsuranceRepository repo;

  AutoInsurancePolicy policy({NoteAttachments? attachments}) =>
      AutoInsurancePolicy(
        id: 0,
        automobileId: 1,
        provider: 'Intact',
        policyNumber: 'POL-1',
        effectiveDate: DateTime.utc(2026, 1, 1),
        expiryDate: DateTime.utc(2027, 1, 1),
        premium: 1200,
        attachments: attachments,
      );

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'insurance-attachments-tester'),
        );
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();

    repo = LocalInsuranceRepository(
      LocalHmmNoteRepository(db, () async => author),
      LocalNoteCatalogRepository(db),
    );
  });

  tearDown(() async => db.close());

  test('an image and a PDF survive a create', () async {
    final created = await repo.createPolicy(
      1,
      policy(attachments: NoteAttachments(images: const [_card], files: const [_policyPdf])),
    );

    expect(created.attachments.images, hasLength(1));
    expect(created.attachments.files, hasLength(1));
    // AttachmentRef is sealed and exposes only `kind`; the detail lives on
    // the VaultRef variant.
    expect((created.attachments.images.single as VaultRef).contentType, 'image/jpeg');
    expect((created.attachments.files.single as VaultRef).originalName, 'policy.pdf');
  });

  test('an attachment survives an edit that has nothing to do with it', () async {
    final created = await repo.createPolicy(
      1,
      policy(attachments: NoteAttachments(images: const [_card])),
    );

    await repo.updatePolicy(
      1,
      created.id,
      AutoInsurancePolicy(
        id: created.id,
        automobileId: 1,
        provider: 'Intact',
        policyNumber: 'POL-RENEWED',
        effectiveDate: created.effectiveDate,
        expiryDate: created.expiryDate,
        premium: 1300,
        attachments: created.attachments,
      ),
    );

    final reloaded = await repo.getPolicyById(1, created.id);
    expect(reloaded.policyNumber, 'POL-RENEWED');
    expect(reloaded.attachments.images, hasLength(1));
  });

  test('clearing attachments actually clears them', () async {
    final created = await repo.createPolicy(
      1,
      policy(attachments: NoteAttachments(images: const [_card])),
    );

    await repo.updatePolicy(
      1,
      created.id,
      AutoInsurancePolicy(
        id: created.id,
        automobileId: 1,
        provider: 'Intact',
        policyNumber: 'POL-1',
        effectiveDate: created.effectiveDate,
        expiryDate: created.expiryDate,
        premium: 1200,
      ),
    );

    final reloaded = await repo.getPolicyById(1, created.id);
    expect(reloaded.attachments.isEmpty, isTrue);
  });

  test('a policy with no attachments reads back empty, never null', () async {
    final created = await repo.createPolicy(1, policy());
    expect(created.attachments.isEmpty, isTrue);
  });
}
