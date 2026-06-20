import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/vault/vault_gc.dart';

void main() {
  test('a files ref is reported as referenced (not collectable)', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 't'));
    const pdf = VaultRef(
        path: 'attachments/n/r.pdf',
        contentType: 'application/pdf',
        byteSize: 3);
    final json =
        NoteAttachmentsCodec.encode(NoteAttachments(files: const [pdf]));
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 's',
          authorId: aid,
          attachments: Value(json),
        ));

    final paths = await collectReferencedVaultPaths(db);
    expect(paths, contains('attachments/n/r.pdf'));
  });
}
