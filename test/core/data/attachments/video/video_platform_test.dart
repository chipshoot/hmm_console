import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hmm/video');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('probe sends paths and parses the result', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return {
        'durationMs': 48000,
        'width': 1080,
        'height': 1920,
        'posterWritten': true,
      };
    });

    final probe = await MethodChannelVideoPlatform().probe(
      '/t/a.mov',
      posterPath: '/t/a.jpg',
    );

    expect(seen!.method, 'probe');
    expect(seen!.arguments, {'path': '/t/a.mov', 'posterPath': '/t/a.jpg'});
    expect(probe.durationMs, 48000);
    expect(probe.width, 1080);
    expect(probe.height, 1920);
    expect(probe.posterWritten, isTrue);
  });

  test('probe tolerates nulls', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'posterWritten': false},
    );

    final probe = await MethodChannelVideoPlatform().probe(
      '/t/a.mov',
      posterPath: '/t/a.jpg',
    );

    expect(probe.durationMs, isNull);
    expect(probe.width, isNull);
    expect(probe.height, isNull);
    expect(probe.posterWritten, isFalse);
  });

  test('saveToPhotos returns the bool', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'saveToPhotos');
      expect(call.arguments, {'path': '/t/a.mov'});
      return false;
    });

    expect(
      await MethodChannelVideoPlatform().saveToPhotos('/t/a.mov'),
      isFalse,
    );
  });

  test('fallback probe is empty', () async {
    final probe = await FallbackVideoPlatform().probe(
      '/t/a.mov',
      posterPath: '/t/a.jpg',
    );
    expect(probe.durationMs, isNull);
    expect(probe.width, isNull);
    expect(probe.height, isNull);
    expect(probe.posterWritten, isFalse);
    expect(await FallbackVideoPlatform().saveToPhotos('/t/a.mov'), isFalse);
  });
}
