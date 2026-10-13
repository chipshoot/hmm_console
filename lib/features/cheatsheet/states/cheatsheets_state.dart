import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/data_mode.dart';
import '../../../core/data/repository_providers.dart';
import '../domain/entities/cheatsheet_card.dart';

/// The wallet's card list.
///
/// Mutations write through the repository and then invalidate, so the list is
/// always re-read from storage rather than patched in memory — the repository
/// upserts by card id, and mirroring that merge logic here is how the two
/// would drift apart.
///
/// The repository is pure persistence, so the vault work for covers —
/// writing picked bytes, deleting released ones — happens here, the same
/// split `DriverLicenceState` uses.
class CheatsheetsState extends AsyncNotifier<List<CheatsheetCard>> {
  @override
  Future<List<CheatsheetCard>> build() =>
      ref.read(cheatsheetRepositoryModeProvider).getCards();

  /// Saves [card]. [newCover] is a picked image to store as the cover;
  /// [released] are covers the edit dropped, deleted only after the write
  /// lands so a failed save never leaves the card pointing at missing bytes.
  Future<void> save(
    CheatsheetCard card, {
    PickedImageBytes? newCover,
    List<VaultRef> released = const [],
  }) async {
    final repo = ref.read(cheatsheetRepositoryModeProvider);
    var next = card;
    if (newCover != null) {
      // Vault paths are keyed by note id, so a brand-new card's note has to
      // exist before its cover can be written.
      var noteId = await repo.noteIdFor(card.id);
      if (noteId == null) {
        await repo.saveCard(card);
        noteId = await repo.noteIdFor(card.id);
      }
      if (noteId == null) {
        throw StateError('card ${card.id} has no note to hold a cover');
      }
      final picker = await ref.read(imageAttachmentPickerProvider.future);
      final cover = await picker.persistToVault(
        noteId: noteId,
        bytes: newCover.bytes,
        originalName: newCover.originalName,
        contentTypeHint: newCover.contentType,
        sensitive: card.protected,
      );
      next = card.withCover(cover);
    }
    await repo.saveCard(next);
    // Never delete the bytes the saved card still points at.
    final kept = next.cover?.path;
    await _release([
      for (final r in released)
        if (r.path != kept) r,
    ]);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    final repo = ref.read(cheatsheetRepositoryModeProvider);
    final cover = (await repo.getCard(id))?.cover;
    await repo.deleteCard(id);
    if (cover != null) await _release([cover]);
    ref.invalidateSelf();
  }

  void refresh() => ref.invalidateSelf();

  /// Best effort: the refs are already gone from the attachments column, so
  /// a failed delete leaves unreferenced bytes that VaultGc reclaims — never
  /// a broken card. cloudApi keeps bytes server-side and is skipped.
  Future<void> _release(List<VaultRef> refs) async {
    if (refs.isEmpty) return;
    if (ref.read(dataModeProvider) == DataMode.cloudApi) return;
    try {
      final store = await ref.read(vaultStoreProvider.future);
      for (final r in refs) {
        await store.delete(r.path);
      }
    } catch (e) {
      // Type only: the error can quote the vault path.
      debugPrint('CheatsheetsState: releasing ${refs.length} cover file(s) '
          'failed (${e.runtimeType}); VaultGc will reclaim them.');
    }
  }
}

final cheatsheetsStateProvider =
    AsyncNotifierProvider<CheatsheetsState, List<CheatsheetCard>>(
  () => CheatsheetsState(),
);
