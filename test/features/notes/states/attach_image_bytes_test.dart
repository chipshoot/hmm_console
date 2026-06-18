import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

const _ref = VaultRef(
    path: 'attachments/note-1/a.jpg', contentType: 'image/jpeg', byteSize: 3);

class _FakePicker implements IImageAttachmentPicker {
  Uint8List? gotBytes;
  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
  }) async {
    gotBytes = bytes;
    return _ref;
  }

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
  test('attachImageBytes persists + appends a VaultRef to the note', () async {
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
    await mutate.attachImageBytes(
      1,
      PickedImageBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          originalName: 'a.jpg',
          contentType: 'image/jpeg'),
    );

    expect(picker.gotBytes, isNotNull);
    expect(repo.written, isNotNull);
    expect(repo.written!.primaryImage, _ref); // first image becomes primary
  });
}
