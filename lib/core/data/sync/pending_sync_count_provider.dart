import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import 'sync_controller.dart';
import 'sync_orchestrator.dart';

/// Cheap "how many local notes haven't reached the cloud yet" count.
/// Drives the persistent Sync pill's badge (`SyncPill`) and the
/// blocked/failed anti-loss prompt (`pending_sync_prompt.dart`). See
/// `docs/superpowers/specs/2026-07-15-sync-safety-persistent-access-design.md`.
///
/// Recomputes whenever:
///   - the Notes table changes (any write, from any feature — mirrors the
///     same drift `.watch()` reactivity `notesListStateProvider` relies
///     on), or
///   - a sync completes (the SyncController ChangeNotifier fires — this
///     catches the case a push advances the cursor without the local Notes
///     row's `lastModifiedDate` changing).
///
/// 0 when no sync orchestrator is active (`local`/`cloudApi` in Phase 1 —
/// see `SyncOrchestrator.isActive`).
final pendingSyncCountProvider = StreamProvider.autoDispose<int>((ref) {
  final orchestrator = ref.watch(syncOrchestratorProvider);
  final controller = ref.watch(syncControllerProvider);
  final db = ref.watch(hmmDatabaseProvider);

  if (!orchestrator.isActive) {
    return Stream.value(0);
  }

  final out = StreamController<int>();

  Future<void> emit() async {
    if (out.isClosed) return;
    out.add(await orchestrator.pendingChangeCount());
  }

  final dbSub = db.select(db.notes).watch().listen((_) => emit());
  void onControllerChange() => emit();
  controller.addListener(onControllerChange);

  ref.onDispose(() {
    dbSub.cancel();
    controller.removeListener(onControllerChange);
    out.close();
  });

  emit(); // Seed the first value without waiting for a table event.

  return out.stream;
});
