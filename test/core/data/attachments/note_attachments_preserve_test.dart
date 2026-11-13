import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';

const videoRef = {
  'kind': 'vault',
  'path': 'attachments/note-1/clip.mov',
  'contentType': 'video/quicktime',
  'byteSize': 900000000,
};
const photo = {
  'kind': 'vault',
  'path': 'attachments/note-1/a.jpg',
  'contentType': 'image/jpeg',
  'byteSize': 10,
};

void main() {
  test('unknown contentType in files is preserved, not thrown', () {
    final a = NoteAttachmentsCodec.decode(
      jsonEncode({
        'images': [photo],
        'files': [videoRef],
      }),
    );
    expect(a.files, isEmpty);
    expect(a.preservedFiles, [videoRef]);
    expect(a.images.single, isA<VaultRef>());
  });
  test('unknown kind in images is preserved', () {
    final odd = {'kind': 'future', 'x': 1};
    expect(
      NoteAttachmentsCodec.decode(
        jsonEncode({
          'images': [odd],
        }),
      ).preservedImages,
      [odd],
    );
  });
  test('unknown top-level key round-trips', () {
    final raw = jsonEncode({
      'images': [photo],
      'linkPreviews': [
        {'url': 'https://youtu.be/x'},
      ],
    });
    final out = jsonDecode(
      NoteAttachmentsCodec.encode(NoteAttachmentsCodec.decode(raw))!,
    );
    expect(out['linkPreviews'], [
      {'url': 'https://youtu.be/x'},
    ]);
  });
  test('unsupported primaryImage is preserved and re-emitted', () {
    final a = NoteAttachmentsCodec.decode(
      jsonEncode({'primaryImage': videoRef, 'images': []}),
    );
    expect(a.primaryImage, isNull);
    expect(
      jsonDecode(NoteAttachmentsCodec.encode(a)!)['primaryImage'],
      videoRef,
    );
  });
  test('full round trip keeps preserved entries after known ones', () {
    final a = NoteAttachmentsCodec.decode(
      jsonEncode({
        'images': [photo],
        'files': [videoRef],
      }),
    );
    final out = jsonDecode(NoteAttachmentsCodec.encode(a)!);
    expect(out['files'], [videoRef]);
    expect(out['images'], [photo]);
  });
  test('only-preserved payload is not empty and encodes', () {
    final a = NoteAttachmentsCodec.decode(
      jsonEncode({
        'files': [videoRef],
      }),
    );
    expect(a.isEmpty, isFalse);
    expect(NoteAttachmentsCodec.encode(a), isNotNull);
  });
  test('copyWith keeps preserved data', () {
    final a = NoteAttachmentsCodec.decode(
      jsonEncode({
        'files': [videoRef],
        'zz': 1,
      }),
    );
    final b = a.copyWith(
      images: [
        const VaultRef(
          path: 'attachments/note-1/b.jpg',
          contentType: 'image/jpeg',
          byteSize: 1,
        ),
      ],
    );
    expect(b.preservedFiles, [videoRef]);
    expect(b.extra, {'zz': 1});
  });
  test('vaultPaths includes preserved vault entries', () {
    final a = NoteAttachmentsCodec.decode(
      jsonEncode({
        'images': [photo],
        'files': [videoRef],
      }),
    );
    expect(a.vaultPaths, {
      'attachments/note-1/a.jpg',
      'attachments/note-1/clip.mov',
    });
  });
  test('structural errors still throw', () {
    expect(
      () => NoteAttachmentsCodec.decode('{"files": {}}'),
      throwsFormatException,
    );
    expect(
      () => NoteAttachmentsCodec.decode(
        jsonEncode({
          'files': [
            {'kind': 'vault', 'contentType': 'image/jpeg', 'byteSize': 1},
          ],
        }),
      ),
      throwsFormatException,
    );
  });
  test('AttachmentRefCodec.fromJson still throws on unknown contentType', () {
    expect(
      () => AttachmentRefCodec.fromJson(videoRef),
      throwsA(isA<UnsupportedAttachmentException>()),
    );
  });
}
