import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/features/notes/presentation/widgets/inline_image_controller.dart';

PickedImageBytes _pick() => PickedImageBytes(
    bytes: Uint8List.fromList([1, 2, 3]),
    originalName: 'a.jpg',
    contentType: 'image/jpeg');

void main() {
  test('stageAndInsert stages bytes and inserts a pending placeholder', () {
    final c = InlineImageController();
    final body = TextEditingController(text: 'x');
    body.selection = const TextSelection.collapsed(offset: 1);
    c.stageAndInsert(body, _pick());
    expect(body.text, contains('hmm-attachment://pending/'));
    expect(c.pendingBytes.values.single, _pick().bytes);
  });

  test('resolveAndRewrite persists picks, rewrites the body, clears state',
      () async {
    final c = InlineImageController();
    final body = TextEditingController();
    c.stageAndInsert(body, _pick());
    const ref = VaultRef(
        path: 'attachments/note-7/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 3);

    final result = await c.resolveAndRewrite(
        noteId: 7, body: body, persist: (_, _) async => ref);

    expect(result.newRefs, [ref]);
    expect(result.hadFailures, isFalse);
    expect(body.text, contains('hmm-attachment://attachments/note-7/a.jpg'));
    expect(body.text, isNot(contains('pending/')));
    expect(c.pendingBytes, isEmpty);
  });

  test('resolveAndRewrite strips a placeholder whose pick fails', () async {
    final c = InlineImageController();
    final body = TextEditingController();
    c.stageAndInsert(body, _pick());

    final result = await c.resolveAndRewrite(
        noteId: 7,
        body: body,
        persist: (_, _) async => throw Exception('boom'));

    expect(result.newRefs, isEmpty);
    expect(result.hadFailures, isTrue);
    expect(body.text, isNot(contains('pending/')));
    expect(body.text, isNot(contains('hmm-attachment://')));
  });

  test('removedImagePaths returns loaded paths no longer in the body', () {
    final removed = InlineImageController.removedImagePaths(
      ['attachments/note-1/a.png', 'attachments/note-1/b.png'],
      'kept ![b](hmm-attachment://attachments/note-1/b.png)',
    );
    expect(removed, ['attachments/note-1/a.png']);
  });
}
