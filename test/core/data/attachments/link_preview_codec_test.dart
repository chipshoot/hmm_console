import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/attachments/link_preview.dart';

const thumb = VaultRef(
  path: 'attachments/note-1/thumb.jpg',
  contentType: 'image/jpeg',
  byteSize: 1234,
);
const photo = {
  'kind': 'vault',
  'path': 'attachments/note-1/a.jpg',
  'contentType': 'image/jpeg',
  'byteSize': 10,
};

void main() {
  test('round-trips a youtube preview with thumbnail', () {
    final a = NoteAttachments(
      linkPreviews: const [
        LinkPreview(
          url: 'https://youtu.be/dQw4w9WgXcQ',
          provider: LinkProvider.youtube,
          title: 'Song',
          durationSeconds: 212,
          thumbnail: thumb,
        ),
      ],
    );
    final back = NoteAttachmentsCodec.decode(NoteAttachmentsCodec.encode(a));
    expect(back, a);
    expect(back.extra, isEmpty);
  });

  test('durationSeconds omitted when null', () {
    const p = LinkPreview(
      url: 'https://x.com/v',
      provider: LinkProvider.web,
      title: 't',
    );
    expect(p.toJson().containsKey('durationSeconds'), isFalse);
    expect(p.toJson().containsKey('thumbnail'), isFalse);
  });

  test('unknown provider decodes as web', () {
    final p = LinkPreview.fromJson({
      'url': 'https://x.com/v',
      'provider': 'vimeo',
      'title': 't',
    });
    expect(p.provider, LinkProvider.web);
  });

  test('missing url or title throws FormatException', () {
    expect(() => LinkPreview.fromJson({'title': 't'}), throwsFormatException);
    expect(
      () => LinkPreview.fromJson({'url': 'https://x.com'}),
      throwsFormatException,
    );
  });

  test('invalid entry is preserved and re-emitted', () {
    const bad = {'weird': true};
    final raw = jsonEncode({
      'images': [photo],
      'linkPreviews': [
        {'url': 'https://x.com/v', 'provider': 'web', 'title': 't'},
        bad,
      ],
    });
    final a = NoteAttachmentsCodec.decode(raw);
    expect(a.linkPreviews, hasLength(1));
    expect(a.preservedLinkPreviews, [bad]);
    expect(a.extra, isEmpty);
    final out = NoteAttachmentsCodec.toJson(a);
    expect((out['linkPreviews'] as List).last, bad);
    expect(out['linkPreviews'], hasLength(2));
  });

  test('vaultPaths includes link thumbnails', () {
    final a = NoteAttachments(
      linkPreviews: const [
        LinkPreview(
          url: 'https://youtu.be/dQw4w9WgXcQ',
          provider: LinkProvider.youtube,
          title: 'Song',
          thumbnail: thumb,
        ),
      ],
    );
    expect(a.vaultPaths, contains('attachments/note-1/thumb.jpg'));
    expect(a.isEmpty, isFalse);
  });

  test('empty linkPreviews keeps old byte-identical output', () {
    final raw = jsonEncode({
      'images': [photo],
    });
    expect(NoteAttachmentsCodec.encode(NoteAttachmentsCodec.decode(raw)), raw);
  });
}
