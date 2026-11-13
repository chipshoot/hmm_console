import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/attachment_providers.dart';
import '../attachments/attachment_ref_codec.dart';
import '../data_mode.dart';
import '../sync/cloud_sync_provider.dart';
import '../sync/pending_remote_purge_store.dart';
import '../sync/sync_models.dart';
import '../sync/sync_orchestrator.dart';
import '../vault/vault_gc.dart';
import '../vault/vault_store.dart';
import 'database.dart';

enum PurgeOutcome { purged, notEligible, keptLiveOnServer, failed }

/// Permanently removes soft-deleted notes (Recently Deleted, G6/G9/G11).
///
/// [purgeExpired] covers EVERY soft-deleted note older than [retention] —
/// entity notes too, so deleted gas logs' and cards' photos finally leave the
/// vault. Callers run it outside sync (`NotePurgeScheduler` uses
/// `SyncController.runExclusive`). Per-mode behaviour is in the plan's Task 8
/// table; every write is guarded by the `deletedAt` value just read, so a
/// restore that lands meanwhile always wins.
class NotePurgeService {
  NotePurgeService({
    required HmmDatabase db,
    required DataMode mode,
    required Future<IVaultStore> Function() baseVaultStore,
    CloudSyncProvider? provider,
    PendingRemotePurgeStore? pending,
    @visibleForTesting Future<void> Function()? afterEligibilityRead,
  }) : _db = db,
       _mode = mode,
       _baseVaultStore = baseVaultStore,
       _provider = provider,
       _pending = pending ?? PendingRemotePurgeStore(),
       _afterEligibilityRead = afterEligibilityRead;

  static const Duration retention = Duration(days: 30);

  final HmmDatabase _db;
  final DataMode _mode;

  /// The store underneath encryption — deleting never needs to decrypt.
  final Future<IVaultStore> Function() _baseVaultStore;
  final CloudSyncProvider? _provider;
  final PendingRemotePurgeStore _pending;

  /// Test seam: runs between the eligibility read and the write, to simulate
  /// a restore landing in that window.
  final Future<void> Function()? _afterEligibilityRead;

  /// Purge every note soft-deleted more than [retention] before [now].
  /// Returns how many were purged.
  Future<int> purgeExpired(DateTime now) async {
    final cutoff = now.toUtc().subtract(retention);
    final candidates =
        await (_db.select(_db.notes)..where(
              (n) =>
                  n.deletedAt.isNotNull() &
                  n.deletedAt.isSmallerThanValue(cutoff),
            ))
            .get();
    var purged = 0;
    for (final row in candidates) {
      if (_mode == DataMode.cloudStorage && _isScrubbedTombstone(row)) continue;
      if (await _purge(row.id, cutoff: cutoff) == PurgeOutcome.purged) purged++;
    }
    return purged;
  }

  /// "Delete now" (slice 5 UI): purge one soft-deleted note immediately.
  Future<PurgeOutcome> purgeNow(int id) => _purge(id, cutoff: null);

  Future<PurgeOutcome> _purge(int id, {required DateTime? cutoff}) async {
    final row = await (_db.select(
      _db.notes,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    final deletedAt = row?.deletedAt;
    if (row == null || deletedAt == null) return PurgeOutcome.notEligible;
    if (cutoff != null && !deletedAt.toUtc().isBefore(cutoff)) {
      return PurgeOutcome.notEligible;
    }

    final paths = _vaultPathsOf(row.attachments);
    await _afterEligibilityRead?.call();
    try {
      // Queue the remote half BEFORE the irreversible scrub: a crash in
      // between leaves a harmless entry (the sync flush discards it while the
      // note is still live) instead of an orphaned OneDrive blob.
      final p = _provider;
      final uuid = row.uuid;
      if (_mode == DataMode.cloudStorage && p != null && uuid != null) {
        await _pending.add(p.providerId, uuid, paths);
      }
      final done = switch (_mode) {
        DataMode.local => await _hardDelete(row.id, row.uuid, deletedAt),
        DataMode.cloudStorage => await _scrubToTombstone(
          row.id,
          row.uuid,
          deletedAt,
        ),
        DataMode.cloudApi => await _purgeOnServerThenDelete(row, deletedAt),
      };
      if (!done) return PurgeOutcome.notEligible;
    } on NoteLiveOnServerException {
      return PurgeOutcome.keptLiveOnServer;
    } catch (e) {
      debugPrint(
        'NotePurgeService: purging note $id failed (${e.runtimeType})',
      );
      return PurgeOutcome.failed;
    }
    // cloudApi bytes live server-side; the purge endpoint released them.
    if (_mode != DataMode.cloudApi) await _releaseVault(paths);
    return PurgeOutcome.purged;
  }

  Future<bool> _purgeOnServerThenDelete(Note row, DateTime deletedAt) async {
    final p = _provider;
    final uuid = row.uuid;
    if (p != null && uuid != null) {
      await p.purgeNote(uuid); // throws NoteLiveOnServerException when live
    }
    return _hardDelete(row.id, uuid, deletedAt);
  }

  Future<bool> _hardDelete(int id, String? uuid, DateTime deletedAt) =>
      _db.transaction(() async {
        final gone = await (_db.delete(
          _db.notes,
        )..where((n) => n.id.equals(id) & n.deletedAt.equals(deletedAt))).go();
        if (gone == 0) return false; // restored meanwhile
        await (_db.delete(
          _db.noteTagRefs,
        )..where((r) => r.noteId.equals(id))).go();
        await _deleteState(uuid);
        await _detachChildren(id);
        return true;
      });

  /// cloudStorage: keep a content-free tombstone so the manifest keeps
  /// propagating the delete. lastModifiedDate is deliberately NOT bumped:
  /// peers keep their own 30-day clock, and a newer restore elsewhere still
  /// wins the pull and refills this row.
  Future<bool> _scrubToTombstone(
    int id,
    String? uuid,
    DateTime deletedAt,
  ) => _db.transaction(() async {
    final changed =
        await (_db.update(
          _db.notes,
        )..where((n) => n.id.equals(id) & n.deletedAt.equals(deletedAt))).write(
          const NotesCompanion(
            subject: Value(kTombstoneSubject),
            content: Value(null),
            description: Value(null),
            attachments: Value(null),
            latitude: Value(null),
            longitude: Value(null),
            locationLabel: Value(null),
            catalogId: Value(null),
            parentNoteId: Value(null),
          ),
        );
    if (changed == 0) return false; // restored meanwhile
    await (_db.delete(_db.noteTagRefs)..where((r) => r.noteId.equals(id))).go();
    await _deleteState(uuid);
    await _detachChildren(id);
    return true;
  });

  /// A purged note's pin/flag goes with it (G14). The note row never held
  /// them; the sync merge drops the remote entry once the note is gone.
  Future<void> _deleteState(String? uuid) async {
    if (uuid == null) return;
    await (_db.delete(
      _db.noteStates,
    )..where((s) => s.noteUuid.equals(uuid))).go();
  }

  /// G12: attached notes become unattached once their parent is purged. The
  /// bump makes the detach sync like any other edit.
  Future<void> _detachChildren(int parentId) async {
    await (_db.update(
      _db.notes,
    )..where((n) => n.parentNoteId.equals(parentId))).write(
      NotesCompanion(
        parentNoteId: const Value(null),
        lastModifiedDate: Value(DateTime.now().toUtc()),
      ),
    );
  }

  bool _isScrubbedTombstone(Note row) =>
      row.subject == kTombstoneSubject &&
      row.content == null &&
      row.attachments == null;

  static Set<String> _vaultPathsOf(String? raw) {
    return NoteAttachmentsCodec.decode(raw).vaultPaths;
  }

  /// Release the purged note's vault files that no remaining note references
  /// (the VaultGc rule). Best effort: leftovers are reclaimed by VaultGc.
  Future<void> _releaseVault(Set<String> paths) async {
    if (paths.isEmpty) return;
    try {
      final stillReferenced = await collectReferencedVaultPaths(_db);
      final store = await _baseVaultStore();
      for (final path in paths) {
        if (!stillReferenced.contains(path)) await store.delete(path);
      }
    } catch (e) {
      debugPrint('NotePurgeService: vault release failed (${e.runtimeType})');
    }
  }
}

final notePurgeServiceProvider = Provider<NotePurgeService>((ref) {
  return NotePurgeService(
    db: ref.watch(hmmDatabaseProvider),
    mode: ref.watch(dataModeProvider),
    baseVaultStore: () => ref.read(baseVaultStoreProvider.future),
    provider: ref.watch(syncOrchestratorProvider).provider,
  );
});
