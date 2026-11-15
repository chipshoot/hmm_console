import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/video_upload_scheduler.dart';

import '../attachments/video/fake_video_platform.dart';

class _FakeRunner implements VideoUploadRunner {
  int loads = 0;
  int runs = 0;
  bool throwOnRun = false;
  Completer<void>? gate;
  @override
  Future<void> load() async => loads++;
  @override
  Future<void> run() async {
    runs++;
    if (gate != null) await gate!.future;
    if (throwOnRun) throw StateError('boom');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRunner runner;
  late FakeVideoPlatform platform;
  late bool syncing;
  late StreamController<List<ConnectivityResult>> net;
  late VideoUploadScheduler scheduler;

  setUp(() {
    runner = _FakeRunner();
    platform = FakeVideoPlatform();
    syncing = false;
    net = StreamController<List<ConnectivityResult>>.broadcast();
    scheduler = VideoUploadScheduler(
      resolveUploader: () async => runner,
      isSyncing: () => syncing,
      platform: platform,
      connectivity: net.stream,
    )..attach();
  });

  tearDown(() async {
    scheduler.dispose();
    await net.close();
  });

  test('runs after a finished sync, loading the uploader once', () async {
    await scheduler.maybeRun();
    await scheduler.maybeRun();
    expect(runner.loads, 1);
    expect(runner.runs, 2);
  });

  test(
    'onAttach runs once on the first attach, not on later attaches',
    () async {
      var calls = 0;
      final s = VideoUploadScheduler(
        resolveUploader: () async => runner,
        isSyncing: () => false,
        platform: platform,
        onAttach: () async => calls++,
      );
      s.attach();
      s.attach();
      await pumpEventQueue();
      expect(calls, 1);
      s.dispose();
      s.attach();
      await pumpEventQueue();
      expect(calls, 1);
      s.dispose();
    },
  );

  test('a throwing onAttach does not stop attach', () async {
    final s = VideoUploadScheduler(
      resolveUploader: () async => runner,
      isSyncing: () => false,
      platform: platform,
      onAttach: () async => throw StateError('x'),
    );
    s.attach();
    await pumpEventQueue();
    s.dispose();
  });

  test('runs on resume', () async {
    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(runner.runs, 1);
    scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
    await pumpEventQueue();
    expect(runner.runs, 1);
  });

  test('runs when Wi-Fi returns, not on cellular', () async {
    net.add([ConnectivityResult.mobile]);
    await pumpEventQueue();
    expect(runner.runs, 0);
    net.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(runner.runs, 1);
  });

  test('holds a background task while running and ends it', () async {
    runner.gate = Completer<void>();
    final f = scheduler.maybeRun();
    await pumpEventQueue();
    expect(platform.beganTasks, 1);
    expect(platform.endedTasks, isEmpty);
    runner.gate!.complete();
    await f;
    expect(platform.endedTasks, [1]);
  });

  test('ends the background task when the run throws', () async {
    runner.throwOnRun = true;
    await scheduler.maybeRun();
    expect(platform.endedTasks, [1]);
  });

  test('fetchMissing still runs when the upload run throws', () async {
    runner.throwOnRun = true;
    var fetches = 0;
    final s = VideoUploadScheduler(
      resolveUploader: () async => runner,
      isSyncing: () => false,
      platform: platform,
      fetchMissing: () async => fetches++,
    );
    await s.maybeRun();
    expect(fetches, 1);
    expect(platform.endedTasks, [1]);
  });

  test('does not run while a sync is in progress', () async {
    syncing = true;
    await scheduler.maybeRun();
    expect(runner.runs, 0);
    expect(platform.beganTasks, 0);
  });

  test('triggers during a run coalesce into exactly one re-run', () async {
    runner.gate = Completer<void>();
    final f = scheduler.maybeRun();
    await pumpEventQueue();
    unawaited(scheduler.maybeRun());
    unawaited(scheduler.maybeRun());
    expect(runner.runs, 1);
    final gate = runner.gate!;
    runner.gate = null;
    gate.complete();
    await f;
    expect(runner.runs, 2);
    expect(platform.beganTasks, 2);
    expect(platform.endedTasks, [1, 2]);
  });

  test('no re-run when a sync started during the run', () async {
    runner.gate = Completer<void>();
    final f = scheduler.maybeRun();
    await pumpEventQueue();
    unawaited(scheduler.maybeRun());
    syncing = true;
    runner.gate!.complete();
    await f;
    expect(runner.runs, 1);
  });
}
