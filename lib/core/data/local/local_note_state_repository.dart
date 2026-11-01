import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/note_state.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_orchestrator.dart';
import 'database.dart';
import 'local_hmm_note_repository.dart' show restoreStamp;

/// Pin + flag per note (Notes redesign G14), keyed by note uuid. Writes go
/// to `NoteStates` only — never to the note row — so they cannot overwrite
/// a concurrent text edit made on another device.
abstract interface class INoteStateRepository {
  /// The stored state, or [NoteState.none] when the note has no row.
  Future<NoteState> getState(String noteUuid);

  /// [getState] now and again after every change to the note's row —
  /// including writes made by sync, so an open screen stays current.
  Stream<NoteState> watchState(String noteUuid);

  /// Every stored state, by note uuid.
  Future<Map<String, NoteState>> getAllStates();

  /// Pin or unpin. Unpin writes `isPinned = false` (never deletes) so the
  /// change propagates. Keeps the flag.
  Future<NoteState> setPinned(String noteUuid, bool pinned);

  /// Set a colour (0–6; any other int is stored verbatim) or clear it with
  /// null (a row with a null flag). Keeps the pin.
  Future<NoteState> setFlagColor(String noteUuid, int? flagColor);
}

class LocalNoteStateRepository implements INoteStateRepository {
  LocalNoteStateRepository(this._db, {void Function()? onLocalWrite})
      : _onLocalWrite = onLocalWrite;

  final HmmDatabase _db;

  /// Asks for a debounced sync (of states — the note cursor is untouched).
  final void Function()? _onLocalWrite;

  @override
  Future<NoteState> getState(String noteUuid) async {
    final row = await _read(noteUuid);
    return row == null ? NoteState.none(noteUuid) : _fromRow(row);
  }

  @override
  Stream<NoteState> watchState(String noteUuid) =>
      (_db.select(_db.noteStates)..where((s) => s.noteUuid.equals(noteUuid)))
          .watchSingleOrNull()
          .map((row) => row == null ? NoteState.none(noteUuid) : _fromRow(row));

  @override
  Future<Map<String, NoteState>> getAllStates() async {
    final rows = await _db.select(_db.noteStates).get();
    return {for (final r in rows) r.noteUuid: _fromRow(r)};
  }

  @override
  Future<NoteState> setPinned(String noteUuid, bool pinned) async {
    final current = await _read(noteUuid);
    return _writeLocal(NoteState(
      noteUuid: noteUuid,
      isPinned: pinned,
      flagColor: current?.flagColor,
      lastModifiedDate: _stamp(current),
    ));
  }

  @override
  Future<NoteState> setFlagColor(String noteUuid, int? flagColor) async {
    final current = await _read(noteUuid);
    return _writeLocal(NoteState(
      noteUuid: noteUuid,
      isPinned: current?.isPinned ?? false,
      flagColor: flagColor,
      lastModifiedDate: _stamp(current),
    ));
  }

  /// Sync only: store [state] exactly as received (its own stamp). Does not
  /// ask for another sync.
  Future<void> putState(NoteState state) async {
    await _db.into(_db.noteStates).insertOnConflictUpdate(_companion(state));
  }

  /// Purge / sync only: remove the row of a note that no longer exists.
  Future<void> deleteState(String noteUuid) async {
    await (_db.delete(_db.noteStates)
          ..where((s) => s.noteUuid.equals(noteUuid)))
        .go();
  }

  Future<NoteState> _writeLocal(NoteState state) async {
    await putState(state);
    _onLocalWrite?.call();
    return getState(state.noteUuid);
  }

  /// Drift keeps whole seconds: a second write inside the same second must
  /// still be strictly newer, or peers would keep the first value on a tie.
  DateTime _stamp(NoteStateRow? current) {
    final now = DateTime.now().toUtc();
    return current == null ? now : restoreStamp(current.lastModifiedDate, now);
  }

  Future<NoteStateRow?> _read(String noteUuid) => (_db.select(_db.noteStates)
        ..where((s) => s.noteUuid.equals(noteUuid)))
      .getSingleOrNull();

  static NoteStatesCompanion _companion(NoteState s) =>
      NoteStatesCompanion.insert(
        noteUuid: s.noteUuid,
        isPinned: Value(s.isPinned),
        flagColor: Value(s.flagColor),
        lastModifiedDate: s.lastModifiedDate.toUtc(),
      );

  static NoteState _fromRow(NoteStateRow r) => NoteState(
        noteUuid: r.noteUuid,
        isPinned: r.isPinned,
        flagColor: r.flagColor,
        lastModifiedDate: r.lastModifiedDate.toUtc(),
      );
}

final localNoteStateRepositoryProvider =
    Provider<LocalNoteStateRepository>((ref) {
  return LocalNoteStateRepository(
    ref.watch(hmmDatabaseProvider),
    // Same debounced auto-sync gate as LocalHmmNoteRepository: read (not
    // watch) both providers since this closure runs later, at write time.
    onLocalWrite: () {
      if (ref.read(syncOrchestratorProvider).isActive) {
        ref.read(syncControllerProvider).notifyLocalChange();
      }
    },
  );
});
