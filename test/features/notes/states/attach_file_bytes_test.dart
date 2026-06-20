import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/file_byte_source.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

const _ref = VaultRef(
    path: 'attachments/note-1/r.pdf',
    contentType: 'application/pdf',
    byteSize: 3);

class _FakePicker implements IImageAttachmentPicker {
  Uint8List? gotBytes;
  String? gotContentType;
  @override
  Future<VaultRef> persistFileToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    required String contentType,
  }) async {
    gotBytes = bytes;
    gotContentType = contentType;
    return _ref;
  }

  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
  }) async =>
      _ref;

  @override
  Future<VaultRef?> pickForNote({
    required int noteId,
    AttachmentPickSource source = AttachmentPickSource.gallery,
  }) async =>
      null;
}

class _FakeRepo implements IHmmNoteRepository {
  _FakeRepo(this.note);
  HmmNote note;
  NoteAttachments? written;
  @override
  Future<HmmNote?> getNoteById(int id) async => note;
  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    written = patch.attachments;
    return note;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('attachFileBytes persists + appends a VaultRef to files', () async {
    final picker = _FakePicker();
    final repo = _FakeRepo(HmmNote(
        id: 1, uuid: 'u', subject: 's', authorId: 1,
        createDate: DateTime(2026, 1, 1)));
    final container = ProviderContainer(overrides: [
      imageAttachmentPickerProvider.overrideWith((ref) async => picker),
      hmmNoteRepositoryProvider.overrideWith((ref) => repo),
    ]);
    addTearDown(container.dispose);

    final mutate = container.read(mutateNoteProvider);
    await mutate.attachFileBytes(
      1,
      PickedFileBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          originalName: 'r.pdf',
          contentType: 'application/pdf'),
    );

    expect(picker.gotBytes, isNotNull);
    expect(picker.gotContentType, 'application/pdf');
    expect(repo.written, isNotNull);
    expect(repo.written!.files, [_ref]);
  });
}
