import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_indicator_state.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';

/// `SyncResult.success` is derived from `errors.isEmpty`, so a failure is
/// simply a result that carries errors.
SyncResult _result({List<SyncError> errors = const []}) => SyncResult(
      pulledNotes: 0,
      pulledAttachments: 0,
      pushedNotes: 0,
      pushedAttachments: 0,
      completedAt: DateTime.utc(2026, 9, 17),
      errors: errors,
    );

const _authError =
    SyncError(recordType: 'auth', recordId: '', message: 'sub claim missing');
const _noteError =
    SyncError(recordType: 'note', recordId: 'n1', message: 'Push failed');

void main() {
  test('Local mode shows NO dot, whatever the status says', () {
    // Absence is the signal: a dot of any colour would claim something
    // about a cloud that is not there.
    const status = SyncStatus(isSyncing: true);
    expect(syncIndicatorStateFor(status, DataMode.local),
        SyncIndicatorState.none);
  });

  test('in flight wins over everything', () {
    final status = SyncStatus(
      isSyncing: true,
      consecutiveFailures: 5,
      lastResult: _result(errors: const [_noteError]),
    );
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.syncing);
  });

  test('a failed last run is failed', () {
    final status = SyncStatus(lastResult: _result(errors: const [_noteError]));
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.failed);
  });

  test('three consecutive failures is failed even with no lastResult', () {
    // The Settings card treats the streak as its own signal; so does this.
    const status = SyncStatus(consecutiveFailures: 3);
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.failed);
  });

  test('held for Wi-Fi is waiting, not failed — even over a stale failure',
      () {
    // Nothing is wrong; the network policy is doing its job. The stale
    // failed result underneath must not win, or every Wi-Fi hold after one
    // bad run would read as broken.
    final status = SyncStatus(
      lastAutoTriggerSkippedForNetwork: true,
      lastResult: _result(errors: const [_noteError]),
    );
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.waiting);
  });

  test('a successful last run is synced', () {
    final status = SyncStatus(
      lastSyncAt: DateTime.utc(2026, 9, 17),
      lastResult: _result(),
    );
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.synced);
  });

  test('never synced yet, in a cloud mode, is waiting', () {
    // Cloud is configured but nothing has run: not a failure, not a success.
    const status = SyncStatus();
    expect(syncIndicatorStateFor(status, DataMode.cloudApi),
        SyncIndicatorState.waiting);
  });

  group('isAuthFailure', () {
    test('true when the last result carries an auth error', () {
      final status =
          SyncStatus(lastResult: _result(errors: const [_authError]));
      expect(isAuthFailure(status), isTrue);
    });

    test('false for an ordinary failure', () {
      final status =
          SyncStatus(lastResult: _result(errors: const [_noteError]));
      expect(isAuthFailure(status), isFalse);
    });

    test('false with no result at all', () {
      expect(isAuthFailure(const SyncStatus()), isFalse);
    });
  });
}
