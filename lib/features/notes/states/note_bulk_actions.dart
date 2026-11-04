import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'mutate_note_state.dart';

/// Result of a bulk write. Ids keep input order.
class BulkOutcome {
  const BulkOutcome({required this.succeeded, required this.failed});
  final List<int> succeeded;
  final List<int> failed;
  int get total => succeeded.length + failed.length;
}

class BulkDeleteOutcome {
  const BulkDeleteOutcome({
    required this.deleted,
    required this.skipped,
    required this.failed,
  });

  /// Moved to Recently Deleted.
  final List<int> deleted;

  /// Entity notes (G7), never written.
  final List<int> skipped;
  final List<int> failed;
}

/// Applies one action to many notes through [MutateNote]. Each id is
/// attempted independently: a failure is recorded and the loop continues.
class NoteBulkActions {
  NoteBulkActions(this._mutate);
  final MutateNote _mutate;

  /// Pins all, unless every id is already pinned (then unpins all).
  Future<(bool pinned, BulkOutcome)> togglePinned(
    List<int> ids,
    Map<int, bool> isPinnedById,
  ) async {
    final pin = !ids.every((id) => isPinnedById[id] ?? false);
    final outcome = await _each(ids, 'pin', (id) => _mutate.setPinned(id, pin));
    return (pin, outcome);
  }

  Future<BulkOutcome> setFlag(List<int> ids, int? flagColor) =>
      _each(ids, 'flag', (id) => _mutate.setFlagColor(id, flagColor));

  /// [isOrdinary] decides eligibility (from canDeleteFromNotes) before any
  /// write; ineligible ids are skipped untouched.
  Future<BulkDeleteOutcome> delete(
    List<int> ids,
    bool Function(int id) isOrdinary,
  ) async {
    final eligible = ids.where(isOrdinary).toList();
    final skipped = ids.where((id) => !isOrdinary(id)).toList();
    final o = await _each(eligible, 'delete', _mutate.delete);
    return BulkDeleteOutcome(
      deleted: o.succeeded,
      skipped: skipped,
      failed: o.failed,
    );
  }

  Future<BulkOutcome> restore(List<int> ids) =>
      _each(ids, 'restore', _mutate.restore);

  Future<BulkOutcome> _each(
    List<int> ids,
    String what,
    Future<Object?> Function(int id) action,
  ) async {
    final ok = <int>[];
    final bad = <int>[];
    for (final id in ids) {
      try {
        await action(id);
        ok.add(id);
      } catch (e) {
        debugPrint('NoteBulkActions: $what failed (${e.runtimeType})');
        bad.add(id);
      }
    }
    return BulkOutcome(succeeded: ok, failed: bad);
  }
}

final noteBulkActionsProvider = Provider<NoteBulkActions>(
  (ref) => NoteBulkActions(ref.watch(mutateNoteProvider)),
);

/// The snackbar text for a bulk delete, or null when nothing was eligible
/// (the caller then shows notesBulkNothingDeleted instead).
String? bulkDeleteMessage(BulkDeleteOutcome o, AppLocalizations l) {
  if (o.deleted.isEmpty) return null;
  return o.skipped.isEmpty
      ? l.notesBulkDeleted(o.deleted.length)
      : l.notesBulkDeletedSkipped(o.deleted.length, o.skipped.length);
}
