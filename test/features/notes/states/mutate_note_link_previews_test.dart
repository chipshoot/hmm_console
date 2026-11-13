import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/link_preview.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/links/link_preview_fetcher.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

const _thumbRef = VaultRef(
  path: 'attachments/note-1/thumb.jpg',
  contentType: 'image/jpeg',
  byteSize: 3,
);

class _FakePicker implements IImageAttachmentPicker {
  _FakePicker({this.fail = false});
  final bool fail;
  final calls = <({String name, String? type})>[];

  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
    bool sensitive = false,
  }) async {
    calls.add((name: originalName, type: contentTypeHint));
    if (fail) throw const AttachmentPickerException('nope');
    return _thumbRef;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
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
    note = HmmNote(
      id: note.id,
      uuid: note.uuid,
      subject: note.subject,
      authorId: note.authorId,
      createDate: note.createDate,
      attachments: patch.attachments ?? note.attachments,
    );
    return note;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _image = VaultRef(
  path: 'attachments/note-1/a.jpg',
  contentType: 'image/jpeg',
  byteSize: 3,
);
const _file = VaultRef(
  path: 'attachments/note-1/b.pdf',
  contentType: 'application/pdf',
  byteSize: 3,
);

HmmNote _note(NoteAttachments? atts) => HmmNote(
  id: 1,
  uuid: 'u',
  subject: 's',
  authorId: 1,
  createDate: DateTime(2026, 1, 1),
  attachments: atts,
);

FetchedLinkPreview _fetched(String url) => FetchedLinkPreview(
  url: url,
  provider: LinkProvider.youtube,
  title: 'A video',
  durationSeconds: 90,
  thumbnailBytes: Uint8List.fromList([1, 2, 3]),
  thumbnailContentType: 'image/jpeg',
);

void main() {
  ProviderContainer containerWith(_FakePicker picker, _FakeRepo repo) {
    final c = ProviderContainer(
      overrides: [
        imageAttachmentPickerProvider.overrideWith((ref) async => picker),
        hmmNoteRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('saves added previews with their persisted thumbnails', () async {
    final picker = _FakePicker();
    final repo = _FakeRepo(_note(null));
    final mutate = containerWith(picker, repo).read(mutateNoteProvider);

    final saved = await mutate.saveLinkPreviews(
      1,
      kept: const [],
      added: [_fetched('https://youtu.be/dQw4w9WgXcQ')],
    );

    expect(picker.calls.single.name, 'link-thumb');
    expect(picker.calls.single.type, 'image/jpeg');
    final p = saved!.effectiveAttachments.linkPreviews.single;
    expect(p.url, 'https://youtu.be/dQw4w9WgXcQ');
    expect(p.title, 'A video');
    expect(p.durationSeconds, 90);
    expect(p.thumbnail, _thumbRef);
  });

  test('failed thumbnail persist saves preview without thumbnail', () async {
    final picker = _FakePicker(fail: true);
    final repo = _FakeRepo(_note(null));
    final mutate = containerWith(picker, repo).read(mutateNoteProvider);

    final saved = await mutate.saveLinkPreviews(
      1,
      kept: const [],
      added: [_fetched('https://youtu.be/dQw4w9WgXcQ')],
    );

    final p = saved!.effectiveAttachments.linkPreviews.single;
    expect(p.url, 'https://youtu.be/dQw4w9WgXcQ');
    expect(p.thumbnail, isNull);
  });

  test('keeps preserved and other attachments', () async {
    const kept = LinkPreview(
      url: 'https://www.bilibili.com/video/BV1xx411c7mD',
      provider: LinkProvider.bilibili,
      title: 'Old',
    );
    const dropped = LinkPreview(
      url: 'https://youtu.be/aaaaaaaaaaa',
      provider: LinkProvider.youtube,
      title: 'Gone',
    );
    final start = NoteAttachments(
      primaryImage: _image,
      files: const [_file],
      preservedImages: const [
        {'kind': 'future', 'x': 1},
      ],
      linkPreviews: const [kept, dropped],
      preservedLinkPreviews: const [
        {'weird': true},
      ],
      extra: const {'videoRefs': 'keep me'},
    );
    final picker = _FakePicker();
    final repo = _FakeRepo(_note(start));
    final mutate = containerWith(picker, repo).read(mutateNoteProvider);

    await mutate.saveLinkPreviews(
      1,
      kept: const [kept],
      added: [_fetched('https://youtu.be/dQw4w9WgXcQ')],
    );

    final w = repo.written!;
    expect(w.primaryImage, _image);
    expect(w.files, const [_file]);
    expect(w.preservedImages, start.preservedImages);
    expect(w.preservedLinkPreviews, start.preservedLinkPreviews);
    expect(w.extra, start.extra);
    expect(w.linkPreviews.map((p) => p.url), [
      kept.url,
      'https://youtu.be/dQw4w9WgXcQ',
    ]);
  });

  test('returns null when the note is gone', () async {
    final picker = _FakePicker();
    final c = ProviderContainer(
      overrides: [
        imageAttachmentPickerProvider.overrideWith((ref) async => picker),
        hmmNoteRepositoryProvider.overrideWith((ref) => _GoneRepo()),
      ],
    );
    addTearDown(c.dispose);
    final r = await c
        .read(mutateNoteProvider)
        .saveLinkPreviews(1, kept: const [], added: const []);
    expect(r, isNull);
  });
}

class _GoneRepo implements IHmmNoteRepository {
  @override
  Future<HmmNote?> getNoteById(int id) async => null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
