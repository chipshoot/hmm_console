import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/attachment_providers.dart';
import '../vault/vault_gc.dart';
import '../vault/vault_store.dart';
import '../../../features/settings/data/syncable_settings_repository.dart';
import '../../../features/settings/domain/syncable_settings.dart';
import '../../../features/settings/providers/settings_bus_provider.dart';
import '../data_mode.dart';
import '../local/database.dart';
import '../local/local_tag_repository.dart';
import 'api_sync_provider.dart';
import 'cloud_sync_provider.dart';
import 'onedrive_sync_provider.dart';
import 'sync_meta_repository.dart';
import 'sync_models.dart';
import 'tag_sync_service.dart';

/// Drives the full sync algorithm (see `docs/sync_contract.md` §4–§6).
///
/// Record identity is the per-row **UUID** (stable across devices). Local
/// int PKs are never sent to the cloud. Cross-table references travel as:
///   - `catalogName` (resolved via `note_catalogs.name`, which is unique)
///   - `parentNoteUuid` (resolved via `notes.uuid`, requires a two-pass pull)
///
/// **Phase 11.5 (2026-05-17):** attachment bytes no longer travel through
/// the orchestrator. The per-note `attachments` JSON column on the `Notes`
/// table now carries the refs (VaultRef paths), and the bytes ride one of
/// two transports depending on the active tier:
/// - `cloudStorage`: the vault root sits inside the user's OneDrive /
///   iCloud Drive folder; the OS-level sync client moves the bytes.
/// - `cloudApi` (Phase 15, not yet implemented): the dedicated
///   `/v1/vault/{path}` API endpoint via a future `ApiVaultStore`.
/// The orchestrator therefore syncs **notes only**.
class SyncOrchestrator {
  SyncOrchestrator({
    required this.provider,
    required HmmDatabase db,
    required SyncMetaRepository meta,
    required Future<IVaultStore> Function() vaultStore,
    SyncableSettingsRepository? settingsRepo,
    void Function()? onSettingsApplied,
  })  : _db = db,
        _meta = meta,
        _vaultStore = vaultStore,
        _settingsRepo = settingsRepo ?? SyncableSettingsRepository(),
        _onSettingsApplied = onSettingsApplied,
        _tagRepo = LocalTagRepository(db);

  /// Null when the current DataMode is Local — no sync.
  final CloudSyncProvider? provider;

  final HmmDatabase _db;
  final SyncMetaRepository _meta;
  final Future<IVaultStore> Function() _vaultStore;
  final SyncableSettingsRepository _settingsRepo;
  final LocalTagRepository _tagRepo;

  /// Fires after a remote settings bundle is applied to local prefs.
  /// In production this calls `SettingsBus.bump()` so the Riverpod
  /// settings notifiers reload from prefs. Optional so tests +
  /// settings-unaware callers (the local-only tier) don't have to
  /// supply a callback.
  final void Function()? _onSettingsApplied;

  bool get isActive => provider != null;

  Future<SyncResult> syncNow() async {
    final p = provider;
    final startedAt = DateTime.now().toUtc();
    if (p == null) {
      return SyncResult.failed(
        at: startedAt,
        error: const SyncError(
          recordType: 'auth',
          recordId: 'none',
          message:
              'No sync provider is active. Switch to Cloud Storage or Cloud (API) in Settings.',
        ),
      );
    }

    final errors = <SyncError>[];
    int pulledNotes = 0;
    int pushedNotes = 0;

    // -------- 0a. Migrate legacy OneDrive layout if needed --------
    // OneDrive used to write notes at `approot/notes/{id}.json` (single
    // shared path for the Microsoft account). After the per-user-isolation
    // change the path is `approot/users/{sub}/notes/{id}.json` — so on
    // first sync after upgrade, the user's pre-existing data would be
    // invisible at the new path. migrateLegacyIfNeeded() copies it into
    // the current user's subtree and writes a marker so it never runs
    // again. Marker check is one HTTP call when the marker exists
    // (cheap). Cast is honest: this is a OneDrive-specific concern that
    // doesn't belong on the abstract CloudSyncProvider interface.
    if (p is OneDriveSyncProvider) {
      try {
        await p.migrateLegacyIfNeeded();
      } catch (e) {
        // Migration failure shouldn't block a regular sync — log it as
        // an error in the result but continue. Worst case: the user has
        // to re-import legacy data manually; the live sync still works.
        errors.add(SyncError(
          recordType: 'manifest',
          recordId: 'legacy-migration',
          message: 'Legacy OneDrive migration failed (continuing): $e',
        ));
      }
    }

    // -------- 0b. Settings (Phase D.2) --------
    // SyncableSettings is a single sibling-file at
    // users/{sub}/settings.json. LWW on the whole bundle keyed by
    // `lastModified`. Independent of note sync — runs first so a
    // settings change can land even if the note legs throw later in
    // the algorithm.
    try {
      await _syncSettings(p, errors);
    } catch (e) {
      errors.add(SyncError(
        recordType: 'manifest',
        recordId: 'settings',
        message: 'Settings sync threw: $e',
      ));
    }

    // Tag definitions sync (independent of notes; non-fatal). Membership
    // rides with the note sync below.
    try {
      await _syncTags(p, errors);
    } catch (e) {
      errors.add(SyncError(
        recordType: 'tags',
        recordId: 'tags.json',
        message: 'Tag sync threw: $e',
      ));
    }

    // -------- 0c. Snapshot local deltas BEFORE pull --------
    // Avoids re-uploading rows that the pull is about to overwrite.
    final cursor = await _meta.getLastPushedAt(p.providerId) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final localNoteBlobs = await _collectChangedNotes(cursor);

    // -------- 1. PULL: manifest --------
    SyncManifest? remote;
    try {
      remote = await p.pullManifest();
    } catch (e) {
      return SyncResult.failed(
        at: startedAt,
        error: SyncError(
          recordType: 'manifest',
          recordId: '-',
          message: 'Failed to pull manifest: $e',
        ),
      );
    }

    // -------- 1b. Backfill push queue with notes missing from remote --------
    // Self-healing patch for cursor drift: any local note whose UUID is
    // NOT present in the remote manifest gets added to the push queue,
    // independent of `lastModifiedDate > cursor`. Catches notes that
    // were created/modified between a successful prior sync (cursor
    // advanced) and a subsequent failed-then-retry sync that never
    // re-collected them. See `findings.md` 2026-05-25.
    //
    // Safe to do AFTER the manifest pull and BEFORE the body-pull loop
    // because the body-pull only touches notes that ARE in the remote
    // manifest — by definition we're collecting the disjoint set, so
    // there's no concern about overwriting just-pulled content.
    final remoteUuids =
        remote?.notes.map((e) => e.id).toSet() ?? const <String>{};
    final missingFromRemote = await _collectMissingFromRemote(
      remoteUuids: remoteUuids,
      alreadyQueued: localNoteBlobs.map((b) => b.id).toSet(),
    );
    localNoteBlobs.addAll(missingFromRemote);

    // Queue of (childLocalId, parentUuid) for pass 2 resolution.
    final pendingParents = <({int childId, String parentUuid})>[];

    // -------- 2. PULL: notes --------
    if (remote != null) {
      for (final entry in remote.notes) {
        try {
          final applied = await _maybePullNote(p, entry, pendingParents);
          if (applied) pulledNotes++;
        } catch (e) {
          errors.add(SyncError(
            recordType: 'note',
            recordId: entry.id,
            message: 'Pull failed: $e',
          ));
        }
      }

      // Pass 2: resolve parentNoteUuid references now that every note is
      // local.
      for (final pending in pendingParents) {
        try {
          final parent = await (_db.select(_db.notes)
                ..where((n) => n.uuid.equals(pending.parentUuid)))
              .getSingleOrNull();
          if (parent != null) {
            await (_db.update(_db.notes)
                  ..where((n) => n.id.equals(pending.childId)))
                .write(NotesCompanion(parentNoteId: Value(parent.id)));
          }
          // Parent not found — leave parentNoteId null; next sync will retry.
        } catch (e) {
          errors.add(SyncError(
            recordType: 'note',
            recordId: pending.parentUuid,
            message: 'Parent resolution failed: $e',
          ));
        }
      }

      // (Attachment-byte pull retired in Phase 11.5 — bytes travel
      // out-of-band via the OS-level cloud sync client when the vault
      // root sits inside the user's OneDrive / iCloud Drive folder.)
    }

    // -------- 3. PUSH: local note changes --------
    for (final blob in localNoteBlobs) {
      try {
        await p.pushNoteBody(blob.id, blob.body);
        pushedNotes++;
      } catch (e) {
        errors.add(SyncError(
          recordType: 'note',
          recordId: blob.id,
          message: 'Push failed: $e',
        ));
      }
    }

    // -------- 4. PUSH: rewritten manifest --------
    try {
      final freshManifest = await _buildManifest();
      await p.pushManifest(freshManifest);
    } catch (e) {
      errors.add(SyncError(
        recordType: 'manifest',
        recordId: '-',
        message: 'Failed to push manifest: $e',
      ));
    }

    // -------- 4b. Reconcile attachment bytes (cloudStorage) --------
    final (pushedAtt, pulledAtt) = await _reconcileVault(p, errors);

    // -------- 5. Advance cursor on a clean run --------
    final completedAt = DateTime.now().toUtc();
    final result = SyncResult(
      pulledNotes: pulledNotes,
      pulledAttachments: pulledAtt,
      pushedNotes: pushedNotes,
      pushedAttachments: pushedAtt,
      completedAt: completedAt,
      errors: errors,
    );
    // Advance the note cursor when the *metadata* sync was clean. Attachment
    // byte transfer is best-effort and explicitly non-fatal: a transient
    // per-file Graph error must NOT hold the cursor back (which would
    // re-collect and re-push every changed note next sync). Such errors still
    // surface in result.errors; the missing bytes are retried next sync.
    final metadataClean =
        errors.every((e) => e.recordType == 'attachment');
    if (metadataClean) {
      await _meta.setLastPushedAt(p.providerId, completedAt);
    }
    return result;
  }

  // ==================== PULL helpers ====================

  Future<bool> _maybePullNote(
    CloudSyncProvider provider,
    ManifestEntry entry,
    List<({int childId, String parentUuid})> pendingParents,
  ) async {
    final uuid = entry.id;

    final local =
        await (_db.select(_db.notes)..where((n) => n.uuid.equals(uuid)))
            .getSingleOrNull();
    final localUpdatedAt = local?.lastModifiedDate ?? local?.createDate;
    if (local != null &&
        localUpdatedAt != null &&
        !entry.updatedAt.isAfter(localUpdatedAt.toUtc())) {
      return false; // LWW: local wins.
    }

    if (entry.deleted) {
      if (local != null) {
        await (_db.update(_db.notes)..where((n) => n.id.equals(local.id)))
            .write(NotesCompanion(
          deletedAt: Value(entry.updatedAt),
          lastModifiedDate: Value(entry.updatedAt),
        ));
      } else {
        // Insert tombstone so it can propagate to this device's peers.
        await _db.into(_db.notes).insert(NotesCompanion.insert(
              uuid: Value(uuid),
              subject: '(deleted)',
              authorId: await _defaultAuthorId(),
              deletedAt: Value(entry.updatedAt),
              lastModifiedDate: Value(entry.updatedAt),
              createDate: Value(entry.updatedAt),
            ));
      }
      return true;
    }

    final body = await provider.pullNoteBody(uuid);
    if (body == null) return false; // Manifest claims it exists, blob gone.

    await _applyPulledNote(uuid, entry, body, local, pendingParents);
    return true;
  }

  Future<void> _applyPulledNote(
    String uuid,
    ManifestEntry entry,
    Map<String, dynamic> body,
    Note? existing,
    List<({int childId, String parentUuid})> pendingParents,
  ) async {
    // Resolve catalog by name (name is unique; ids are device-local).
    int? catalogId;
    final catalogName = body['catalogName'] as String?;
    if (catalogName != null && catalogName.isNotEmpty) {
      final existingCat = await (_db.select(_db.noteCatalogs)
            ..where((c) => c.name.equals(catalogName)))
          .getSingleOrNull();
      if (existingCat != null) {
        catalogId = existingCat.id;
      } else {
        catalogId = await _db.into(_db.noteCatalogs).insert(
              NoteCatalogsCompanion.insert(name: catalogName, schema: '{}'),
            );
      }
    }

    final createDateRaw = body['createDate'] as String?;
    final createDate = createDateRaw != null
        ? DateTime.tryParse(createDateRaw) ?? entry.updatedAt
        : (existing?.createDate ?? entry.updatedAt);

    // Editable note date (Phase 2a). Absent (older client) ⇒ leave a stored
    // value untouched on update, and fall back to createDate on insert.
    final noteDateRaw = body['noteDate'] as String?;
    final noteDate = noteDateRaw != null ? DateTime.tryParse(noteDateRaw) : null;

    // Phase 2b location: present key ⇒ apply (set), absent ⇒ preserve.
    final hasLocation = body.containsKey('latitude');
    final lat = (body['latitude'] as num?)?.toDouble();
    final lng = (body['longitude'] as num?)?.toDouble();
    final locLabel = body['locationLabel'] as String?;

    // Phase 3a attachments JSON: present key ⇒ apply, absent ⇒ preserve.
    final hasAttachments = body.containsKey('attachments');
    final attachmentsJson = body['attachments'] as String?;

    final parentUuid = body['parentNoteUuid'] as String?;

    int childId;
    if (existing != null) {
      await (_db.update(_db.notes)..where((n) => n.id.equals(existing.id)))
          .write(NotesCompanion(
        subject: Value(body['subject'] as String? ?? existing.subject),
        content: Value(body['content'] as String?),
        catalogId: Value(catalogId),
        parentNoteId: const Value(null), // resolved in pass 2
        description: Value(body['description'] as String?),
        noteDate:
            noteDate != null ? Value(noteDate) : const Value.absent(),
        latitude: hasLocation ? Value(lat) : const Value.absent(),
        longitude: hasLocation ? Value(lng) : const Value.absent(),
        locationLabel: hasLocation ? Value(locLabel) : const Value.absent(),
        attachments:
            hasAttachments ? Value(attachmentsJson) : const Value.absent(),
        lastModifiedDate: Value(entry.updatedAt),
        deletedAt: Value(entry.deleted ? entry.updatedAt : null),
      ));
      childId = existing.id;
    } else {
      final authorId = await _defaultAuthorId();
      childId = await _db.into(_db.notes).insert(
            NotesCompanion.insert(
              uuid: Value(uuid),
              subject: body['subject'] as String? ?? '(untitled)',
              content: Value(body['content'] as String?),
              authorId: authorId,
              catalogId: Value(catalogId),
              description: Value(body['description'] as String?),
              createDate: Value(createDate),
              noteDate: Value(noteDate ?? createDate),
              latitude: Value(lat),
              longitude: Value(lng),
              locationLabel: Value(locLabel),
              attachments: Value(attachmentsJson),
              lastModifiedDate: Value(entry.updatedAt),
              deletedAt: Value(entry.deleted ? entry.updatedAt : null),
            ),
          );
    }

    if (parentUuid != null && parentUuid.isNotEmpty) {
      pendingParents.add((childId: childId, parentUuid: parentUuid));
    }

    // Rebuild tag membership from the note body (set-replace). The body's
    // tag list is the complete current set; absence means removal.
    final tagNames =
        (body['tags'] as List?)?.whereType<String>().toList() ??
            const <String>[];
    await _tagRepo.setTagsForNote(childId, tagNames);
  }

  Future<int> _defaultAuthorId() async {
    final any = await (_db.select(_db.authors)..limit(1)).getSingleOrNull();
    if (any != null) return any.id;
    return _db.into(_db.authors).insert(
          AuthorsCompanion.insert(accountName: 'local-user'),
        );
  }

  // ==================== SETTINGS sync (Phase D.2) ====================

  /// Pull-then-push the user's settings bundle with whole-bundle LWW
  /// keyed by `lastModified`. Path: `users/{sub}/settings.json`.
  ///
  /// Three outcomes, no errors:
  ///   - Cloud has nothing → push local (seed)
  ///   - Cloud has a newer bundle → apply to local prefs + fire
  ///     `_onSettingsApplied` so the UI reloads
  ///   - Local has a newer bundle → push local (overwrites cloud)
  ///   - Both equal → no-op
  Future<void> _syncSettings(
    CloudSyncProvider p,
    List<SyncError> errors,
  ) async {
    final localSettings = await _settingsRepo.read();

    Map<String, dynamic>? remoteJson;
    try {
      remoteJson = await p.pullSettings();
    } catch (e) {
      // Surface as a non-fatal error and continue with notes — pulled
      // settings can wait until the next sync.
      errors.add(SyncError(
        recordType: 'manifest',
        recordId: 'settings',
        message: 'Failed to pull settings: $e',
      ));
      return;
    }

    if (remoteJson == null) {
      // Cloud is empty; seed it with local. Skip if local is itself
      // still at epoch zero (i.e. fresh install, user hasn't touched
      // any setting yet) — no point uploading an all-defaults blob.
      if (localSettings.lastModified == SyncableSettings.epochZero) return;
      await _pushSettings(p, localSettings, errors);
      return;
    }

    // A malformed / partial remote bundle must not crash the whole
    // sync. Decode defensively: surface a non-fatal error and skip the
    // settings leg, leaving notes to sync normally.
    final SyncableSettings remote;
    try {
      remote = SyncableSettings.fromJson(remoteJson);
    } catch (e) {
      errors.add(SyncError(
        recordType: 'manifest',
        recordId: 'settings',
        message: 'Ignored malformed remote settings: $e',
      ));
      return;
    }
    if (remote.lastModified.isAfter(localSettings.lastModified)) {
      await _settingsRepo.apply(remote);
      _onSettingsApplied?.call();
      return;
    }
    if (localSettings.lastModified.isAfter(remote.lastModified)) {
      await _pushSettings(p, localSettings, errors);
      return;
    }
    // Equal — no-op.
  }

  Future<void> _pushSettings(
    CloudSyncProvider p,
    SyncableSettings local,
    List<SyncError> errors,
  ) async {
    try {
      await p.pushSettings(local.toJson());
    } catch (e) {
      errors.add(SyncError(
        recordType: 'manifest',
        recordId: 'settings',
        message: 'Failed to push settings: $e',
      ));
    }
  }

  // ==================== TAGS sync ====================

  Future<void> _syncTags(CloudSyncProvider p, List<SyncError> errors) async {
    Map<String, dynamic>? remote;
    try {
      remote = await p.pullTags();
    } catch (e) {
      errors.add(SyncError(
        recordType: 'tags',
        recordId: 'tags.json',
        message: 'Failed to pull tags: $e',
      ));
      return;
    }

    final deviceId = await _meta.getOrCreateDeviceId();
    final merged = await TagSyncService(_tagRepo)
        .mergeDefinitions(remote, deviceId: deviceId, now: DateTime.now());
    await p.pushTags(merged);
  }

  // ==================== PUSH collection ====================

  Future<List<NoteBlob>> _collectChangedNotes(DateTime cursor) async {
    final rows = await (_db.select(_db.notes)
          ..where((n) => n.lastModifiedDate.isBiggerThanValue(cursor)))
        .get();
    if (rows.isEmpty) return [];

    // Batch resolve catalog names and parent uuids.
    final catalogIds = rows.map((r) => r.catalogId).whereType<int>().toSet();
    final parentIds = rows.map((r) => r.parentNoteId).whereType<int>().toSet();

    final catalogNames = <int, String>{};
    if (catalogIds.isNotEmpty) {
      final cats = await (_db.select(_db.noteCatalogs)
            ..where((c) => c.id.isIn(catalogIds)))
          .get();
      for (final c in cats) {
        catalogNames[c.id] = c.name;
      }
    }

    final parentUuids = <int, String>{};
    if (parentIds.isNotEmpty) {
      final parents = await (_db.select(_db.notes)
            ..where((n) => n.id.isIn(parentIds)))
          .get();
      for (final parent in parents) {
        final u = parent.uuid;
        if (u != null) parentUuids[parent.id] = u;
      }
    }

    final blobs = <NoteBlob>[];
    for (final n in rows) {
      if (n.uuid == null) continue; // Shouldn't happen post-migration.
      final tagNames = await _tagRepo.tagNamesForNote(n.id);
      blobs.add(_noteRowToBlob(n, catalogNames, parentUuids, tagNames));
    }
    return blobs;
  }

  /// Self-healing fallback for the cursor-drift bug (`findings.md`
  /// 2026-05-25). Iterates every local non-deleted note and returns
  /// blobs for the ones whose UUID is NOT in [remoteUuids] AND NOT
  /// already queued in [alreadyQueued] — i.e., the disjoint set that
  /// `_collectChangedNotes` would silently skip because their mtime
  /// already fell below the cursor.
  ///
  /// Deleted-locally + missing-from-remote is intentionally INCLUDED:
  /// pushing the tombstone propagates the deletion to other devices
  /// (and matches what `_buildManifest` already does — it serialises
  /// tombstones into the outgoing manifest).
  Future<List<NoteBlob>> _collectMissingFromRemote({
    required Set<String> remoteUuids,
    required Set<String> alreadyQueued,
  }) async {
    final allRows = await _db.select(_db.notes).get();
    final missing = <Note>[];
    for (final n in allRows) {
      final uuid = n.uuid;
      if (uuid == null) continue;
      if (remoteUuids.contains(uuid)) continue;
      if (alreadyQueued.contains(uuid)) continue;
      missing.add(n);
    }
    if (missing.isEmpty) return const [];

    // Same catalog/parent-uuid batch resolution as
    // `_collectChangedNotes`. Factored out so this stays readable; if
    // we end up with a third caller it's worth extracting properly.
    final catalogIds = missing.map((r) => r.catalogId).whereType<int>().toSet();
    final parentIds = missing.map((r) => r.parentNoteId).whereType<int>().toSet();

    final catalogNames = <int, String>{};
    if (catalogIds.isNotEmpty) {
      final cats = await (_db.select(_db.noteCatalogs)
            ..where((c) => c.id.isIn(catalogIds)))
          .get();
      for (final c in cats) {
        catalogNames[c.id] = c.name;
      }
    }

    final parentUuids = <int, String>{};
    if (parentIds.isNotEmpty) {
      final parents = await (_db.select(_db.notes)
            ..where((n) => n.id.isIn(parentIds)))
          .get();
      for (final parent in parents) {
        final u = parent.uuid;
        if (u != null) parentUuids[parent.id] = u;
      }
    }

    final blobs = <NoteBlob>[];
    for (final n in missing) {
      final tagNames = await _tagRepo.tagNamesForNote(n.id);
      blobs.add(_noteRowToBlob(n, catalogNames, parentUuids, tagNames));
    }
    return blobs;
  }

  NoteBlob _noteRowToBlob(
    Note n,
    Map<int, String> catalogNames,
    Map<int, String> parentUuids,
    List<String> tagNames,
  ) {
    final updatedAt = (n.lastModifiedDate ?? n.createDate).toUtc();
    final uuid = n.uuid!;
    final catalogName =
        n.catalogId != null ? catalogNames[n.catalogId!] : null;
    final parentUuid =
        n.parentNoteId != null ? parentUuids[n.parentNoteId!] : null;
    return NoteBlob(
      id: uuid,
      body: {
        'uuid': uuid,
        'subject': n.subject,
        'content': n.content,
        'catalogName': catalogName,
        'parentNoteUuid': parentUuid,
        'description': n.description,
        'createDate': n.createDate.toUtc().toIso8601String(),
        // Editable note date (Phase 2a). Distinct from createDate (audit).
        // Older clients omit it; the inbound apply falls back to createDate.
        'noteDate': n.noteDate?.toUtc().toIso8601String(),
        // Optional note location (Phase 2b). Older clients omit these keys;
        // the inbound apply preserves the stored value when absent.
        'latitude': n.latitude,
        'longitude': n.longitude,
        'locationLabel': n.locationLabel,
        // Attachment refs (images + files). Bytes ride OS-level vault sync;
        // this carries the refs so they propagate across devices.
        'attachments': n.attachments,
        'lastModifiedDate': updatedAt.toIso8601String(),
        'deletedAt': n.deletedAt?.toUtc().toIso8601String(),
        'tags': tagNames,
      },
      updatedAt: updatedAt,
      deleted: n.deletedAt != null,
    );
  }

  // ==================== Manifest build ====================

  /// Push local-only referenced vault files up and eagerly pull remote-only
  /// referenced files down. Only runs for providers that move bytes
  /// (cloudStorage/OneDrive). Per-file failures are collected, never fatal.
  /// Returns (pushed, pulled).
  Future<(int, int)> _reconcileVault(
      CloudSyncProvider p, List<SyncError> errors) async {
    if (!p.supportsAttachments) return (0, 0);
    final vault = await _vaultStore();
    final referenced = await collectReferencedVaultPaths(_db);
    final remote = await p.listAttachmentPaths();
    var pushed = 0, pulled = 0;
    for (final path in referenced) {
      final localHas = await vault.exists(path);
      final remoteHas = remote.contains(path);
      if (localHas && !remoteHas) {
        try {
          await p.pushAttachment(path, await vault.getBytes(path));
          pushed++;
        } catch (e) {
          errors.add(SyncError(
              recordType: 'attachment', recordId: path,
              message: 'push failed: $e'));
        }
      } else if (!localHas && remoteHas) {
        try {
          final bytes = await p.pullAttachment(path);
          // null = listed-but-gone (deleted between list and get, or a
          // transient null). Leave the byte missing; the next sync retries.
          if (bytes != null) {
            await vault.putBytes(path, bytes,
                contentType: _contentTypeForPath(path));
            pulled++;
          }
        } catch (e) {
          errors.add(SyncError(
              recordType: 'attachment', recordId: path,
              message: 'pull failed: $e'));
        }
      }
    }
    return (pushed, pulled);
  }

  static String? _contentTypeForPath(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'm4a' => 'audio/mp4',
      // Unknown extension: store a generic binary type rather than null so a
      // future API vault store has a sensible content type to forward.
      _ => 'application/octet-stream',
    };
  }

  Future<SyncManifest> _buildManifest() async {
    final deviceId = await _meta.getOrCreateDeviceId();
    final allNotes = await _db.select(_db.notes).get();

    return SyncManifest(
      version: 1,
      generatedAt: DateTime.now().toUtc(),
      deviceId: deviceId,
      notes: allNotes
          .where((n) => n.uuid != null)
          .map((n) {
        final updatedAt = (n.lastModifiedDate ?? n.createDate).toUtc();
        return ManifestEntry(
          id: n.uuid!,
          updatedAt: updatedAt,
          deleted: n.deletedAt != null,
        );
      }).toList(),
      // Phase 11.5: attachment bytes no longer ride the manifest;
      // the per-note `attachments` column on each note carries the
      // refs, and the bytes travel out-of-band (cloudStorage → OS
      // sync client; cloudApi → future ApiVaultStore).
      attachments: const [],
    );
  }
}

final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) {
  final mode = ref.watch(dataModeProvider);
  final db = ref.watch(hmmDatabaseProvider);
  final meta = ref.watch(syncMetaRepositoryProvider);

  CloudSyncProvider? provider;
  switch (mode) {
    case DataMode.local:
      provider = null;
      break;
    case DataMode.cloudApi:
      provider = ref.watch(apiSyncProviderProvider);
      break;
    case DataMode.cloudStorage:
      final cp = ref.watch(cloudProviderProvider);
      provider = switch (cp) {
        CloudProvider.onedrive => ref.watch(oneDriveSyncProviderProvider),
      };
      break;
  }
  return SyncOrchestrator(
    provider: provider,
    db: db,
    meta: meta,
    vaultStore: () => ref.read(vaultStoreProvider.future),
    settingsRepo: ref.watch(syncableSettingsRepositoryProvider),
    // After a pulled settings bundle is applied to prefs, bump the
    // bus so the per-feature settings notifiers reload from disk and
    // the UI reflects the new values immediately.
    onSettingsApplied: () => ref.read(settingsBusProvider.notifier).bump(),
  );
});
