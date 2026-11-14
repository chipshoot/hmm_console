import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'fake_video_platform.dart';

void main() {
  test('classifyVideoSize thresholds', () {
    const mib = 1024 * 1024;
    expect(classifyVideoSize(500 * mib), VideoSizeVerdict.ok);
    expect(classifyVideoSize(500 * mib + 1), VideoSizeVerdict.warn);
    expect(classifyVideoSize(2048 * mib), VideoSizeVerdict.warn);
    expect(classifyVideoSize(2048 * mib + 1), VideoSizeVerdict.refuse);
  });

  test('videoContentTypeFor', () {
    expect(videoContentTypeFor('IMG_1.MOV'), 'video/quicktime');
    expect(videoContentTypeFor('a.mp4'), 'video/mp4');
    expect(videoContentTypeFor('a.avi'), isNull);
  });

  group('pick', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('vp'));
    tearDown(() => dir.deleteSync(recursive: true));

    VideoPicker picker(String? name, FakeVideoPlatform platform) {
      return VideoPicker(
        pickFile: () async {
          if (name == null) return null;
          final f = File('${dir.path}/$name')
            ..writeAsBytesSync(List.filled(10, 7));
          return XFile(f.path, name: name);
        },
        platform: platform,
        tempDir: () async => dir,
      );
    }

    test('returns poster bytes and deletes the poster temp', () async {
      final p = await picker('a.mov', FakeVideoPlatform()).pick();
      expect(p!.posterBytes, [1, 2, 3]);
      expect(p.byteSize, 10);
      expect(p.contentType, 'video/quicktime');
      expect(p.durationMs, 48000);
      expect(dir.listSync().map((e) => e.path.split('/').last), ['a.mov']);
    });

    test('unsupported type throws and deletes the temp file', () async {
      await expectLater(
        picker('a.avi', FakeVideoPlatform()).pick(),
        throwsA(
          isA<VideoPickException>().having(
            (e) => e.error,
            'error',
            VideoPickError.unsupported,
          ),
        ),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('cancel returns null', () async {
      expect(await picker(null, FakeVideoPlatform()).pick(), isNull);
    });
  });
}
