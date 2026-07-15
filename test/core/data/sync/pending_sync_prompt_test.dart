import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/pending_sync_prompt.dart';

void main() {
  group('shouldPromptPendingSync', () {
    test('false when nothing is pending', () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 0,
          autoSyncSkippedForNetwork: true,
          lastSyncFailed: true,
        ),
        isFalse,
      );
    });

    test('false when pending but auto-sync is neither blocked nor failing',
        () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 3,
          autoSyncSkippedForNetwork: false,
          lastSyncFailed: false,
        ),
        isFalse,
      );
    });

    test('true when pending AND blocked by the WiFi-only network policy',
        () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 1,
          autoSyncSkippedForNetwork: true,
          lastSyncFailed: false,
        ),
        isTrue,
      );
    });

    test('true when pending AND the last sync failed', () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 1,
          autoSyncSkippedForNetwork: false,
          lastSyncFailed: true,
        ),
        isTrue,
      );
    });

    test('true when both blocked and failed', () {
      expect(
        shouldPromptPendingSync(
          pendingCount: 5,
          autoSyncSkippedForNetwork: true,
          lastSyncFailed: true,
        ),
        isTrue,
      );
    });
  });

  test('pendingSyncPromptThreshold is a small positive constant', () {
    expect(pendingSyncPromptThreshold, greaterThan(0));
    expect(pendingSyncPromptThreshold, lessThanOrEqualTo(10));
  });
}
