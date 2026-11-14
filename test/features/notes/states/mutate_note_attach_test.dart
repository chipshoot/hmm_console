import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/file_byte_source.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePicker implements IImageAttachmentPicker {
  @override
  Future<VaultRef?> pickForNote({
    required int noteId,
    AttachmentPickSource source = AttachmentPickSource.gallery,
  }) async => VaultRef(
    path: 'attachments/note-$noteId/picked.jpg',
    contentType: 'image/jpeg',
    byteSize: 1,
  );
  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
    bool sensitive = false,
  }) async => VaultRef(
    path: 'attachments/note-$noteId/img.jpg',
    contentType: 'image/jpeg',
    byteSize: bytes.length,
  );
  @override
  Future<VaultRef> persistFileToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    required String contentType,
    bool sensitive = false,
  }) async => VaultRef(
    path: 'attachments/note-$noteId/doc.pdf',
    contentType: contentType,
    byteSize: bytes.length,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await db.select(db.authors).getSingle();
    container = ProviderContainer(
      overrides: [
        hmmDatabaseProvider.overrideWithValue(db),
        imageAttachmentPickerProvider.overrideWith(
          (ref) async => _FakePicker(),
        ),
        localHmmNoteRepositoryProvider.overrideWithValue(
          LocalHmmNoteRepository(db, () async => author),
        ),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('createGeneral with a parent sets parentNoteId', () async {
    final parentId = await db
        .into(db.notes)
        .insert(NotesCompanion.insert(subject: 'P', authorId: 1));
    final note = await container
        .read(mutateNoteProvider)
        .createGeneral(subject: 'child', parentNoteId: parentId);
    expect(note.parentNoteId, parentId);
  });

  test('attachExisting then detach', () async {
    final parentId = await db
        .into(db.notes)
        .insert(NotesCompanion.insert(subject: 'P', authorId: 1));
    final note = await container
        .read(mutateNoteProvider)
        .createGeneral(subject: 'free');
    expect(note.parentNoteId, isNull);

    final attached = await container
        .read(mutateNoteProvider)
        .attachExisting(note.id, parentId);
    expect(attached.parentNoteId, parentId);

    final detached = await container
        .read(mutateNoteProvider)
        .detachNote(note.id);
    expect(detached.parentNoteId, isNull);
  });

  test('mutate keeps preserved data', () async {
    const videoRef = {
      'kind': 'vault',
      'path': 'attachments/note-1/clip.mov',
      'contentType': 'video/quicktime',
      'byteSize': 9,
    };
    final id = await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            subject: 'v',
            authorId: 1,
            attachments: Value(
              jsonEncode({
                'files': [videoRef],
                'linkPreviews': [
                  {'url': 'u'},
                ],
              }),
            ),
          ),
        );
    final m = container.read(mutateNoteProvider);

    await m.attachFileBytes(
      id,
      PickedFileBytes(
        bytes: Uint8List.fromList([1]),
        originalName: 'a.pdf',
        contentType: 'application/pdf',
      ),
    );
    await m.addImage(id);
    await m.attachImageBytes(
      id,
      PickedImageBytes(bytes: Uint8List.fromList([2]), originalName: 'b.jpg'),
    );

    final raw = (await (db.select(
      db.notes,
    )..where((t) => t.id.equals(id))).getSingle()).attachments!;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    expect(
      (json['files'] as List).map((e) => jsonEncode(e)),
      contains(jsonEncode(videoRef)),
    );
    expect(json['linkPreviews'], [
      {'url': 'u'},
    ]);
    expect((json['files'] as List).length, 2);
    expect(json['primaryImage'], isNotNull);
  });
}
