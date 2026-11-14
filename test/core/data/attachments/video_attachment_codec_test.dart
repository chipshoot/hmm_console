import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';

Map<String, dynamic> _entry({bool poster = true, Map<String, dynamic>? more}) =>
    {
      'video': {
        'kind': 'vault',
        'path': 'attachments/note-5/u1.mov',
        'contentType': 'video/quicktime',
        'byteSize': 123,
        'originalName': 'IMG_1.MOV',
      },
      if (poster)
        'poster': {
          'kind': 'vault',
          'path': 'attachments/note-5/u1.jpg',
          'contentType': 'image/jpeg',
          'byteSize': 4567,
        },
      'durationMs': 48000,
      'width': 1920,
      'height': 1080,
      ...?more,
    };

NoteAttachments _decode(Map<String, dynamic> json) =>
    NoteAttachmentsCodec.decode(jsonEncode(json));

void main() {
  test('round trips a video with poster and metadata', () {
    final a = _decode({
      'images': [],
      'videos': [_entry()],
    });
    final back = NoteAttachmentsCodec.decode(NoteAttachmentsCodec.encode(a));
    expect(back, a);
    expect(a.videos.single.durationMs, 48000);
    expect(a.videos.single.width, 1920);
    expect(a.videos.single.height, 1080);
    expect(a.videos.single.inlinePath, 'attachments/note-5/u1.jpg');
  });

  test('video without poster uses the video path inline', () {
    final a = _decode({
      'videos': [_entry(poster: false)],
    });
    expect(a.videos.single.poster, isNull);
    expect(a.videos.single.inlinePath, 'attachments/note-5/u1.mov');
  });

  test('keeps unknown keys inside an entry', () {
    final a = _decode({
      'videos': [
        _entry(more: {'keepOffline': true}),
      ],
    });
    expect(a.videos.single.extra['keepOffline'], true);
    final out = NoteAttachmentsCodec.toJson(a)['videos'] as List;
    expect((out.single as Map)['keepOffline'], true);
  });

  test('bad entries are preserved raw and their paths still count', () {
    final badAvi = {
      'video': {
        'kind': 'vault',
        'path': 'attachments/note-5/a.avi',
        'contentType': 'video/avi',
        'byteSize': 9,
      },
      'poster': {
        'kind': 'vault',
        'path': 'attachments/note-5/a.jpg',
        'contentType': 'image/jpeg',
        'byteSize': 9,
      },
    };
    final a = _decode({
      'videos': ['x', badAvi, _entry()],
    });
    expect(a.videos, hasLength(1));
    expect(a.preservedVideos, hasLength(2));
    final out = NoteAttachmentsCodec.toJson(a)['videos'] as List;
    expect(out, hasLength(3));
    expect((out.first as Map)['video']['path'], 'attachments/note-5/u1.mov');
    expect(out[1], 'x');
    expect(out[2], badAvi);
    expect(
      a.vaultPaths,
      containsAll([
        'attachments/note-5/a.avi',
        'attachments/note-5/a.jpg',
        'attachments/note-5/u1.mov',
        'attachments/note-5/u1.jpg',
      ]),
    );
  });

  test('non-list videos goes to extra', () {
    final a = _decode({
      'images': [],
      'videos': {'a': 1},
    });
    expect(a.extra['videos'], {'a': 1});
    expect(a.videos, isEmpty);
    expect(NoteAttachmentsCodec.toJson(a)['videos'], {'a': 1});
  });

  test('copyWith keeps videos and preserved ones', () {
    final a = _decode({
      'videos': ['x', _entry()],
    });
    const img = VaultRef(
      path: 'attachments/note-5/i.jpg',
      contentType: 'image/jpeg',
      byteSize: 1,
    );
    final b = a.copyWith(images: [img]);
    expect(b.videos, a.videos);
    expect(b.preservedVideos, a.preservedVideos);
    final c = a.copyWith(videos: []);
    expect(c.videos, isEmpty);
    expect(c.preservedVideos, ['x']);
  });

  test('hasSensitive', () {
    expect(
      _decode({
        'videos': [_entry()],
      }).hasSensitive,
      isFalse,
    );
    expect(
      NoteAttachments(
        images: const [
          VaultRef(
            path: 'attachments/note-5/s.jpg',
            contentType: 'image/jpeg',
            byteSize: 1,
            sensitive: true,
          ),
        ],
      ).hasSensitive,
      isTrue,
    );
    expect(
      NoteAttachments(
        preservedImages: const [
          {
            'kind': 'vault',
            'path': 'attachments/note-5/s.heif',
            'contentType': 'image/heif',
            'byteSize': 1,
            'sensitive': true,
          },
        ],
      ).hasSensitive,
      isTrue,
    );
  });

  test('videoForInlinePath', () {
    final a = _decode({
      'videos': [
        _entry(),
        {
          'video': {
            'kind': 'vault',
            'path': 'attachments/note-5/u2.mp4',
            'contentType': 'video/mp4',
            'byteSize': 5,
          },
        },
      ],
    });
    expect(
      a.videoForInlinePath('attachments/note-5/u1.jpg')?.video.path,
      'attachments/note-5/u1.mov',
    );
    expect(
      a.videoForInlinePath('attachments/note-5/u2.mp4')?.video.path,
      'attachments/note-5/u2.mp4',
    );
    expect(a.videoForInlinePath('attachments/note-5/nope.jpg'), isNull);
  });

  test('isVideoVaultPath', () {
    expect(isVideoVaultPath('a/b.MOV'), isTrue);
    expect(isVideoVaultPath('a/b.mp4'), isTrue);
    expect(isVideoVaultPath('a/b.jpg'), isFalse);
    expect(isVideoVaultPath('a/mov'), isFalse);
  });

  test('fromJson rejects negative numbers', () {
    expect(
      () => VideoAttachment.fromJson(_entry(more: {'durationMs': -1})),
      throwsFormatException,
    );
  });
}
