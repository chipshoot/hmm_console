import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache.dart';
import 'package:hmm_console/core/data/attachments/video/video_platform.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/video_upload_scheduler.dart';

import '../attachments/video/fake_video_platform.dart';

class _Controller extends ChangeNotifier implements SyncController {
  @override
  SyncStatus get status => const SyncStatus();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeCache implements VideoCache {
  final calls = <String>[];
  @override
  Future<int> sweepStaleParts() async {
    calls.add('sweepStaleParts');
    return 0;
  }

  @override
  Future<List<String>> evictToFit({Set<String> protect = const {}}) async {
    calls.add('evictToFit');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('building the scheduler sweeps stale parts and trims the video cache '
      'once at launch', () async {
    final cache = _FakeCache();
    final c = ProviderContainer(
      overrides: [
        syncControllerProvider.overrideWithValue(_Controller()),
        videoPlatformProvider.overrideWithValue(FakeVideoPlatform()),
        videoCacheProvider.overrideWith((ref) async => cache),
      ],
    );
    addTearDown(c.dispose);

    c.read(videoUploadSchedulerProvider);
    await pumpEventQueue();

    expect(cache.calls, ['sweepStaleParts', 'evictToFit']);
  });
}
