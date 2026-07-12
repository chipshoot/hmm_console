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
  Future<VaultRef> persistFileToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    required String contentType,
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
  int updateCalls = 0;
  @override
  Future<HmmNote?> getNoteById(int id) async => note;
  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    updateCalls++;
    written = patch.attachments;
    return note;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  ProviderContainer containerWith(_FakePicker picker, _FakeRepo repo) {
    final c = ProviderContainer(overrides: [
      imageAttachmentPickerProvider.overrideWith((ref) async => picker),
      hmmNoteRepositoryProvider.overrideWith((ref) => repo),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  HmmNote note() => HmmNote(
      id: 1, uuid: 'u', subject: 's', authorId: 1,
      createDate: DateTime(2026, 1, 1));

  test('persistInlineImage returns the VaultRef and does NOT touch attachments',
      () async {
    final picker = _FakePicker();
    final repo = _FakeRepo(note());
    final mutate = containerWith(picker, repo).read(mutateNoteProvider);

    final vref = await mutate.persistInlineImage(
      1,
      PickedImageBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          originalName: 'a.jpg',
          contentType: 'image/jpeg'),
    );

    expect(vref, _ref);
    expect(picker.gotBytes, isNotNull);
    expect(repo.updateCalls, 0); // attachments not modified
    expect(repo.written, isNull);
  });

  test('setAttachments writes the attachments column verbatim', () async {
    final picker = _FakePicker();
    final repo = _FakeRepo(note());
    final mutate = containerWith(picker, repo).read(mutateNoteProvider);

    final atts = NoteAttachments(images: const [_ref]);
    await mutate.setAttachments(1, atts);

    expect(repo.updateCalls, 1);
    expect(repo.written, isNotNull);
    expect(repo.written!.images, const [_ref]);
  });
}
