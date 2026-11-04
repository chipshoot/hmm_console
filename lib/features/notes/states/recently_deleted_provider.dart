import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../../../core/data/local/database.dart' show NoteCatalog;
import '../data/models/hmm_note.dart';
import 'note_delete_policy.dart';

/// How long a deleted note stays in Recently Deleted before it is purged.
const int kRecentlyDeletedDays = 30;

/// Test seam for the clock.
final recentlyDeletedNowProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

/// Whole days left before purge: 30 for a note deleted just now, 1 during the
/// last day. Callers hide notes deleted >= 30 days ago before calling.
int daysLeftFor(DateTime deletedAt, DateTime now) {
  final elapsed = now.toUtc().difference(deletedAt.toUtc());
  final left = kRecentlyDeletedDays - elapsed.inDays;
  return left.clamp(1, kRecentlyDeletedDays);
}

class DeletedNoteItem {
  const DeletedNoteItem({required this.note, required this.daysLeft});

  final HmmNote note;
  final int daysLeft;
}

final _deletedCatalogsProvider = StreamProvider.autoDispose<List<NoteCatalog>>((
  ref,
) {
  return ref.watch(noteCatalogRepositoryProvider).watchCatalogs();
});

/// Ordinary notes (G11) deleted < 30 days ago, newest deletion first. Entity
/// notes (contacts, gas logs, ...) are restored by their own feature.
final recentlyDeletedProvider =
    StreamProvider.autoDispose<List<DeletedNoteItem>>((ref) async* {
      final now = ref.read(recentlyDeletedNowProvider)();
      final catalogs = await ref.watch(_deletedCatalogsProvider.future);
      final nameById = {for (final c in catalogs) c.id: c.name};
      yield* ref.watch(hmmNoteRepositoryProvider).watchDeletedNotes().map((
        notes,
      ) {
        final items = <DeletedNoteItem>[];
        for (final n in notes) {
          final at = n.deletedAt;
          if (at == null) continue;
          if (now.toUtc().difference(at.toUtc()) >=
              const Duration(days: kRecentlyDeletedDays)) {
            continue;
          }
          if (!canDeleteFromNotes(n, nameById[n.catalogId])) continue;
          items.add(DeletedNoteItem(note: n, daysLeft: daysLeftFor(at, now)));
        }
        items.sort((a, b) => b.note.deletedAt!.compareTo(a.note.deletedAt!));
        return items;
      });
    });

/// Every soft-deleted note id, any catalog (G12 parent label).
final deletedNoteIdsProvider = StreamProvider.autoDispose<Set<int>>((ref) {
  return ref
      .watch(hmmNoteRepositoryProvider)
      .watchDeletedNotes()
      .map((notes) => {for (final n in notes) n.id});
});
