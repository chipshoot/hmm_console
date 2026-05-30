// Vault garbage collection — reclaim attachment bytes that no note
// references any more.
//
// Why this exists: the picker writes bytes into the vault the moment
// a photo is picked (so a preview can render), but a note row only
// gains the matching `VaultRef` when the user *saves*. Cancel-after-
// pick, replace-after-pick, and Remove-then-save therefore leave
// orphaned files on disk. This sweep compares every file under the
// vault root against the set of paths still referenced by some note
// and deletes the stragglers.
//
// Scope: filesystem tiers only (`local` + `cloudStorage`, both backed
// by `LocalVaultStore`). The `cloudApi` tier keeps bytes server-side
// and `ApiVaultStore.list('')` is unimplemented, so callers must not
// run the sweep there — the Settings entry point is hidden in
// cloudApi mode.
//
// Safety: a sweep run *while a photo is picked but not yet saved*
// would delete the pending file. The entry point is therefore a
// deliberate, user-triggered Settings action (never an automatic
// background timer), so the user isn't mid-pick when it runs.

import '../local/database.dart';
import '../attachments/attachment_ref.dart';
import '../attachments/attachment_ref_codec.dart';
import 'vault_store.dart';

/// Outcome of one [VaultGarbageCollector.sweep].
class VaultGcResult {
  const VaultGcResult({
    required this.deletedPaths,
    required this.bytesReclaimed,
  });

  /// Vault relative paths that were deleted (or, for a dry run, that
  /// *would* be deleted). Sorted, mirroring [IVaultStore.list].
  final List<String> deletedPaths;

  /// Total size of the deleted files, in bytes.
  final int bytesReclaimed;

  int get deletedCount => deletedPaths.length;

  /// True when nothing needed reclaiming — the vault is already tidy.
  bool get isClean => deletedPaths.isEmpty;

  @override
  String toString() => 'VaultGcResult(deleted: $deletedCount, '
      'bytesReclaimed: $bytesReclaimed)';
}

/// Deletes vault files that no longer belong to any note.
class VaultGarbageCollector {
  const VaultGarbageCollector(this._store);

  final IVaultStore _store;

  /// Delete every file under the vault root whose relative path is
  /// NOT in [referencedPaths].
  ///
  /// [referencedPaths] MUST be the complete set of vault paths still
  /// pointed at by some note (see [collectReferencedVaultPaths]).
  /// Passing an incomplete set would delete live attachments — this
  /// method trusts its caller.
  ///
  /// When [dryRun] is true, nothing is deleted; the result still
  /// reports what *would* have been removed (used to preview counts
  /// in a confirmation dialog before the user commits).
  Future<VaultGcResult> sweep(
    Set<String> referencedPaths, {
    bool dryRun = false,
  }) async {
    final onDisk = await _store.list('');

    var bytes = 0;
    final deleted = <String>[];
    for (final entry in onDisk) {
      if (referencedPaths.contains(entry.relativePath)) continue;
      if (!dryRun) {
        await _store.delete(entry.relativePath);
      }
      deleted.add(entry.relativePath);
      bytes += entry.byteSize;
    }
    // `list` already returns sorted entries, so `deleted` stays sorted.
    return VaultGcResult(deletedPaths: deleted, bytesReclaimed: bytes);
  }
}

/// Read every note's `attachments` column and collect the relative
/// paths of all `vault`-kind refs (the only kind with bytes on disk).
///
/// Includes soft-deleted notes on purpose: a tombstoned note still
/// owns its attachment bytes until it is hard-deleted, so excluding
/// it here would let the sweep reclaim files a restore would need.
///
/// `phasset` / `cloudFile` refs are skipped — their bytes live in
/// Photos / a cloud-drive folder, never in our vault.
Future<Set<String>> collectReferencedVaultPaths(HmmDatabase db) async {
  final rows = await db.select(db.notes).get();
  final paths = <String>{};
  for (final row in rows) {
    final attachments = NoteAttachmentsCodec.decode(row.attachments);
    final refs = <AttachmentRef?>[
      attachments.primaryImage,
      ...attachments.images,
    ];
    for (final ref in refs) {
      if (ref is VaultRef) {
        paths.add(ref.path);
      }
    }
  }
  return paths;
}
