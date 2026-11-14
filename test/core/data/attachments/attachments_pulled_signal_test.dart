import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachments_pulled_signal.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';

SyncResult _result({required int pulledAttachments}) => SyncResult(
  pulledNotes: 1,
  pulledAttachments: pulledAttachments,
  pushedNotes: 0,
  pushedAttachments: 3,
  completedAt: DateTime.utc(2026, 11, 14),
);

void main() {
  test('fires when a sync downloaded attachment files', () {
    final signal = AttachmentsPulledSignal();
    addTearDown(signal.dispose);
    var fired = 0;
    signal.addListener(() => fired++);

    signal.onSyncResult(_result(pulledAttachments: 1));

    expect(fired, 1);
  });

  test('stays quiet when a sync downloaded none (pushes alone do not count)',
      () {
    final signal = AttachmentsPulledSignal();
    addTearDown(signal.dispose);
    var fired = 0;
    signal.addListener(() => fired++);

    signal.onSyncResult(_result(pulledAttachments: 0));

    expect(fired, 0);
  });
}
