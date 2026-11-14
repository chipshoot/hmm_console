import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_models.dart';

/// Fires after a sync downloads attachment files. A note's record can arrive
/// a moment before its files (same sync, files fetched after the notes), so
/// an image or video poster that found nothing on its first try listens here
/// and loads again (`AttachmentImage.retryOn`).
class AttachmentsPulledSignal extends ChangeNotifier {
  void onSyncResult(SyncResult result) {
    if (result.pulledAttachments > 0) notifyListeners();
  }
}

final attachmentsPulledSignalProvider = Provider<AttachmentsPulledSignal>((
  ref,
) {
  final signal = AttachmentsPulledSignal();
  ref.onDispose(signal.dispose);
  return signal;
});
