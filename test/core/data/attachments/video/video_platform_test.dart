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

  test('excludeFromBackup sends the path', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return null;
    });
    await MethodChannelVideoPlatform().excludeFromBackup('/t/dir');
    expect(seen!.method, 'excludeFromBackup');
    expect(seen!.arguments, {'path': '/t/dir'});
  });

  test('beginBackgroundTask returns the id', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return 7;
    });
    expect(await MethodChannelVideoPlatform().beginBackgroundTask(), 7);
    expect(seen!.method, 'beginBackgroundTask');
  });

  test('endBackgroundTask sends the id', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return null;
    });
    await MethodChannelVideoPlatform().endBackgroundTask(7);
    expect(seen!.method, 'endBackgroundTask');
    expect(seen!.arguments, {'id': 7});
  });

  test('fallback background helpers are no-ops', () async {
    final f = FallbackVideoPlatform();
    await f.excludeFromBackup('/t/dir');
    expect(await f.beginBackgroundTask(), isNull);
    await f.endBackgroundTask(1);
  });
}
