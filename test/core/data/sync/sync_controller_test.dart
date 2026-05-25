import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';

/// Coverage for [SyncController] — the scheduling layer that turns
/// lifecycle events + a periodic timer into calls on the (fake) sync
/// action. No real Flutter binding needed beyond
/// `TestWidgetsFlutterBinding.ensureInitialized()` so we can register the
/// observer and pump `didChangeAppLifecycleState`.
///
/// Throttle + clock are driven via the injected [ClockNow] so we never
/// have to actually wait 30 s in tests; lifecycle is driven via
/// `WidgetsBinding.instance.handleAppLifecycleStateChanged` so the
/// real observer dispatch path runs.
void main() {
  // initialise the test binding once for the whole file so we can
  // register WidgetsBindingObserver.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClock clock;
  late _FakeSyncAction action;

  setUp(() {
    clock = _FakeClock(DateTime.utc(2026, 1, 1, 12));
    action = _FakeSyncAction();
  });

  SyncController buildController({
    Duration throttle = const Duration(seconds: 30),
    Duration periodic = const Duration(minutes: 10),
    Duration debounce = const Duration(milliseconds: 250),
  }) =>
      SyncController(
        syncAction: action.call,
        throttle: throttle,
        periodicInterval: periodic,
        foregroundDebounce: debounce,
        now: clock.now,
      );

  group('triggerAutoSync', () {
    test('fires when nothing has run yet', () async {
      final c = buildController();
      final result = await c.triggerAutoSync(SyncTriggerReason.periodic);

      expect(result, isNotNull);
      expect(action.callCount, equals(1));
      expect(c.status.lastReason, equals(SyncTriggerReason.periodic));
      c.dispose();
    });

    test('drops silently when an auto-trigger is inside the throttle window',
        () async {
      final c = buildController(throttle: const Duration(seconds: 30));

      await c.triggerAutoSync(SyncTriggerReason.appForeground);
      clock.advance(const Duration(seconds: 5)); // < 30s throttle

      final result = await c.triggerAutoSync(SyncTriggerReason.periodic);
      expect(result, isNull);
      expect(action.callCount, equals(1));
      c.dispose();
    });

    test('fires again once throttle has elapsed', () async {
      final c = buildController(throttle: const Duration(seconds: 30));

      await c.triggerAutoSync(SyncTriggerReason.appForeground);
      clock.advance(const Duration(seconds: 31)); // > 30s

      final result = await c.triggerAutoSync(SyncTriggerReason.periodic);
      expect(result, isNotNull);
      expect(action.callCount, equals(2));
      c.dispose();
    });

    test('coalesces: an in-flight sync drops further auto-triggers',
        () async {
      final c = buildController();
      action.completer = Completer<SyncResult>();

      // Fire the first trigger and stash its future — don't await yet.
      final first = c.triggerAutoSync(SyncTriggerReason.appForeground);
      // While that's pending, fire another. It should drop.
      final second = c.triggerAutoSync(SyncTriggerReason.periodic);
      expect(await second, isNull);
      expect(action.callCount, equals(1));

      // Complete the in-flight call so the test doesn't hang.
      action.completer!.complete(_successResult(clock.now()));
      await first;
      c.dispose();
    });
  });

  group('triggerManualSync', () {
    test('bypasses the throttle (user just asked)', () async {
      final c = buildController(throttle: const Duration(seconds: 30));

      await c.triggerAutoSync(SyncTriggerReason.appForeground);
      // No clock advance — well inside the throttle window.
      final manual = await c.triggerManualSync();

      expect(manual, isNotNull);
      expect(action.callCount, equals(2));
      c.dispose();
    });

    test('still respects in-flight (returns null when busy)', () async {
      final c = buildController();
      action.completer = Completer<SyncResult>();

      final first = c.triggerAutoSync(SyncTriggerReason.appForeground);
      final manual = await c.triggerManualSync();
      expect(manual, isNull);
      expect(action.callCount, equals(1));

      action.completer!.complete(_successResult(clock.now()));
      await first;
      c.dispose();
    });
  });

  group('lifecycle hooks', () {
    test('debounces appForeground — only fires once after multiple resumes',
        () async {
      final c =
          buildController(debounce: const Duration(milliseconds: 50));
      c.start();

      // Simulate iOS double-bounce: resumed → inactive → resumed in
      // quick succession when a notification banner drops.
      _emitLifecycle(AppLifecycleState.resumed);
      _emitLifecycle(AppLifecycleState.inactive);
      _emitLifecycle(AppLifecycleState.resumed);

      // Wait past the debounce window.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(action.callCount, equals(1),
          reason: 'two resumes within debounce should collapse to one sync');
      c.dispose();
    });

    test('appBackground fires sync immediately + cancels periodic timer',
        () async {
      final c = buildController(periodic: const Duration(milliseconds: 80));
      c.start();

      _emitLifecycle(AppLifecycleState.paused);

      // Microtask + small delay so the unawaited background trigger
      // completes inline (action returns synchronously by default).
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(action.callCount, equals(1));

      // If the periodic timer were still alive it'd fire after 80 ms.
      // It shouldn't — paused cancelled it.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(action.callCount, equals(1));
      c.dispose();
    });

    test('periodic timer restarts on foreground', () async {
      final c = buildController(
        periodic: const Duration(milliseconds: 50),
        debounce: const Duration(milliseconds: 1),
        throttle: Duration.zero, // disable throttle for this test
      );
      c.start();

      // Initial periodic fires once...
      await Future<void>.delayed(const Duration(milliseconds: 70));
      final initial = action.callCount;

      _emitLifecycle(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final afterPause = action.callCount;
      // paused fires its own background sync, so count went up by 1.
      expect(afterPause, equals(initial + 1));

      // Wait through what would have been more periodic ticks while
      // paused — they shouldn't fire.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(action.callCount, equals(afterPause));

      // Resume restarts the periodic.
      _emitLifecycle(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(action.callCount, greaterThan(afterPause));
      c.dispose();
    });

    test('start is idempotent + stop unregisters the observer', () {
      final c = buildController();
      c.start();
      c.start(); // no throw, no double-register
      c.stop();
      c.stop(); // no throw, no double-unregister
      // No assertion to make beyond "didn't throw" — the framework
      // would log a duplicate-removal error if our guard were broken.
    });
  });

  group('SyncStatus updates', () {
    test('isSyncing flips true → false around the action', () async {
      final c = buildController();
      action.completer = Completer<SyncResult>();

      final inFlight = c.triggerAutoSync(SyncTriggerReason.manual);
      expect(c.status.isSyncing, isTrue);

      action.completer!.complete(_successResult(clock.now()));
      await inFlight;
      expect(c.status.isSyncing, isFalse);
      c.dispose();
    });

    test('consecutiveFailures increments on failure, resets on success',
        () async {
      final c = buildController(throttle: Duration.zero);

      action.nextResult = () => _failedResult(clock.now(), 'boom-1');
      await c.triggerAutoSync(SyncTriggerReason.periodic);
      expect(c.status.consecutiveFailures, equals(1));

      action.nextResult = () => _failedResult(clock.now(), 'boom-2');
      await c.triggerAutoSync(SyncTriggerReason.periodic);
      expect(c.status.consecutiveFailures, equals(2));

      action.nextResult = () => _successResult(clock.now());
      await c.triggerAutoSync(SyncTriggerReason.periodic);
      expect(c.status.consecutiveFailures, equals(0),
          reason: 'success resets the failure streak');

      c.dispose();
    });

    test('throws from the action are caught + recorded as a SyncResult',
        () async {
      final c = buildController();
      action.throwInstead = StateError('network gone');

      final result = await c.triggerAutoSync(SyncTriggerReason.periodic);

      expect(result, isNotNull);
      expect(result!.success, isFalse);
      expect(result.errors.first.recordType, equals('transport'));
      expect(c.status.consecutiveFailures, equals(1));
      c.dispose();
    });
  });
}

/// Drive the real `WidgetsBindingObserver` dispatch by tickling the
/// binding's app-state machine. Mirrors what `flutter run` does when iOS
/// / Android pushes a state change through the platform channel.
void _emitLifecycle(AppLifecycleState state) {
  WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
}

class _FakeClock {
  _FakeClock(this._t);
  DateTime _t;
  DateTime now() => _t;
  void advance(Duration d) => _t = _t.add(d);
}

class _FakeSyncAction {
  int callCount = 0;

  /// Set this to make the action block until a manual `.complete()` —
  /// used to assert in-flight coalescing.
  Completer<SyncResult>? completer;

  /// Set this to throw instead of returning normally.
  Object? throwInstead;

  /// Set this to control the next normal-return result (failure cases).
  SyncResult Function()? nextResult;

  Future<SyncResult> call() async {
    callCount++;
    if (throwInstead != null) {
      throw throwInstead!;
    }
    if (completer != null) {
      return completer!.future;
    }
    return (nextResult ?? () => _successResult(DateTime.utc(2026, 1, 1)))();
  }
}

SyncResult _successResult(DateTime at) => SyncResult(
      pulledNotes: 0,
      pulledAttachments: 0,
      pushedNotes: 0,
      pushedAttachments: 0,
      completedAt: at,
    );

SyncResult _failedResult(DateTime at, String message) => SyncResult.failed(
      at: at,
      error: SyncError(
        recordType: 'manifest',
        recordId: '-',
        message: message,
      ),
    );
