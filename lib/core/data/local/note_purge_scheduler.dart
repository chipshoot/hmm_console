import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/sync_controller.dart';
import 'note_purge_service.dart';

/// Runs the 30-day Recently-Deleted purge at most once a day and never while
/// a sync runs (spec "Recently Deleted → Purge", G6/G11).
class NotePurgeScheduler {
  NotePurgeScheduler({
    required Future<int> Function(DateTime now) purgeExpired,
    required SyncController controller,
    DateTime Function()? now,
  }) : _purgeExpired = purgeExpired,
       _controller = controller,
       _now = now ?? DateTime.now;

  /// Device-local: each device purges its own store on its own clock.
  static const String lastRunKey = 'notes_purge_last_run_at';
  static const Duration interval = Duration(days: 1);

  final Future<int> Function(DateTime now) _purgeExpired;
  final SyncController _controller;
  final DateTime Function() _now;
  bool _running = false;

  /// Purge if a day has passed since the last completed run and no sync is
  /// in flight. Returns how many notes were purged, or null when skipped or
  /// failed (a skipped or failed run is not recorded, so it retries soon).
  Future<int?> maybeRun() async {
    if (_running) return null;
    _running = true;
    try {
      final now = _now().toUtc();
      final prefs = await SharedPreferences.getInstance();
      final last = DateTime.tryParse(prefs.getString(lastRunKey) ?? '');
      if (last != null && now.difference(last) < interval) return null;

      final purged = await _controller.runExclusive(() => _purgeExpired(now));
      if (purged == null) return null; // a sync was running
      await prefs.setString(lastRunKey, now.toIso8601String());
      return purged;
    } catch (e) {
      debugPrint('NotePurgeScheduler: purge run failed (${e.runtimeType})');
      return null;
    } finally {
      _running = false;
    }
  }
}

/// Rebuilt with the sync controller (data-mode switches). Re-checks after
/// every sync finishes; `MainApp` also calls [NotePurgeScheduler.maybeRun]
/// once after the first frame, which covers `local` mode (it never syncs).
final notePurgeSchedulerProvider = Provider<NotePurgeScheduler>((ref) {
  final controller = ref.watch(syncControllerProvider);
  final service = ref.watch(notePurgeServiceProvider);
  final scheduler = NotePurgeScheduler(
    purgeExpired: service.purgeExpired,
    controller: controller,
  );
  void afterSync() {
    if (!controller.status.isSyncing) unawaited(scheduler.maybeRun());
  }

  controller.addListener(afterSync);
  ref.onDispose(() => controller.removeListener(afterSync));
  return scheduler;
});
