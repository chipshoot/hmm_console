import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/inline_ref_uri.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/note_sharer.dart';

HmmNote _note({
  String subject = 'Trip',
  String? body,
  NoteAttachments? attachments,
}) => HmmNote(
  id: 1,
  uuid: 'u1',
  subject: subject,
  content: body,
  authorId: 1,
  createDate: DateTime(2026),
  attachments: attachments,
);

void main() {
  test('subject and body are joined by a blank line', () {
    expect(shareTextFor(_note(body: '**Day 1**')), 'Trip\n\n**Day 1**');
  });

  test('an empty or null body shares the subject alone', () {
    expect(shareTextFor(_note(body: '')), 'Trip');
    expect(shareTextFor(_note()), 'Trip');
  });

  group('video placeholder', () {
    const poster = 'attachments/n/v.jpg';
    VideoAttachment video(int? ms) => VideoAttachment(
      video: const VaultRef(
        path: 'attachments/n/v.mov',
        contentType: 'video/quicktime',
        byteSize: 9,
      ),
      poster: const VaultRef(
        path: poster,
        contentType: 'image/jpeg',
        byteSize: 1,
      ),
      durationMs: ms,
    );
    final line = '![Video](${formatImageUri(poster)})';
    HmmNote withVideo(String body, {int? ms = 48000}) => _note(
      body: body,
      attachments: NoteAttachments(videos: [video(ms)]),
    );

    test('a video line becomes a play mark with its length', () {
      expect(
        shareTextFor(withVideo('Wind\n\n$line\n\nafter')),
        'Trip\n\nWind\n\n▶ Video, 0:48\n\nafter',
      );
    });

    test('an unknown length drops the length', () {
      expect(
        shareTextFor(withVideo('Wind\n\n$line', ms: null)),
        'Trip\n\nWind\n\n▶ Video',
      );
    });

    test('a photo line is left unchanged', () {
      final photo = '![p](${formatImageUri('attachments/n/p.jpg')})';
      expect(
        shareTextFor(withVideo('$photo\n\n$line')),
        'Trip\n\n$photo\n\n▶ Video, 0:48',
      );
    });

    test('the label is localizable', () {
      expect(
        shareTextFor(withVideo(line), videoLabel: '视频'),
        'Trip\n\n▶ 视频, 0:48',
      );
    });

    test('an image inline in a longer line is replaced in place', () {
      expect(
        shareTextFor(withVideo('see $line here')),
        'Trip\n\nsee ▶ Video, 0:48 here',
      );
    });
  });
}
