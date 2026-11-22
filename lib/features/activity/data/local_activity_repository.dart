import 'dart:async';
import 'dart:convert';

import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/local/local_hmm_note_repository.dart';
import '../../../core/data/local/local_note_catalog_repository.dart';
import '../../notes/data/models/hmm_note.dart';
import '../contract/activity_errors.dart';
import '../contract/i_activity_repository.dart';
import '../domain/activity.dart';
import 'activity_codec.dart';

const activityCatalogName = 'Hmm.ActivityMan.Activity';
const _catalogSchema = '{"type":"activity"}';

/// The subject is identity: everything else lives in the JSON.
String activitySubjectFor(String id) => 'Activity:$id';

/// Stores each activity as the JSON content of a note in the
/// `Hmm.ActivityMan.Activity` catalog; the note uuid is the activity id.
class LocalActivityRepository implements IActivityRepository {
  LocalActivityRepository(
    this._notes,
    this._catalogs, {
    DateTime Function()? now,
    Duration changesRetryDelay = const Duration(seconds: 1),
  }) : _now = now ?? DateTime.now,
       _changesRetryDelay = changesRetryDelay;

  final IHmmNoteRepository _notes;
  final INoteCatalogRepository _catalogs;
  final DateTime Function() _now;

  /// Wait before re-subscribing when the notes watch fails or ends.
  final Duration _changesRetryDelay;

  static const _pageSize = 100;

  /// The activity catalog's id, created on first use. Two first-run callers
  /// can race the select-then-insert (the name is UNIQUE); the loser
  /// re-reads the winner's row instead of failing.
  Future<int> _catalogId() async {
    try {
      return (await _catalogs.getOrCreateCatalog(
        activityCatalogName,
        _catalogSchema,
      )).id;
    } catch (_) {
      final existing = await _catalogs.getCatalogByName(activityCatalogName);
      if (existing == null) rethrow;
      return existing.id;
    }
  }

  Activity _decode(HmmNote note) {
    try {
      final json = jsonDecode(note.content ?? '');
      if (json is! Map) throw ActivityUnreadable(note.uuid);
      return ActivityCodec.decode(note.uuid, json.cast<String, Object?>());
    } on ActivityUnreadable {
      rethrow;
    } catch (_) {
      throw ActivityUnreadable(note.uuid);
    }
  }

  Future<List<HmmNote>> _allNotes() async {
    final catalogId = await _catalogId();
    final out = <HmmNote>[];
    var page = 1;
    while (true) {
      final res = await _notes.getNotes(
        catalogId: catalogId,
        page: page,
        pageSize: _pageSize,
      );
      out.addAll(res.items);
      if (res.items.isEmpty || page >= res.meta.totalPages) break;
      page++;
    }
    return out;
  }

  /// A live note of this catalog under [id]; soft-deleted rows are absent.
  Future<HmmNote?> _liveNote(String id) async {
    if (id.isEmpty) return null;
    final note = await _notes.getNoteByUuid(id);
    if (note == null || note.deletedAt != null) return null;
    if (note.catalogId != await _catalogId()) return null;
    return note;
  }

  @override
  Future<List<Activity>> activitiesBetween(
    DateTime from,
    DateTime to, {
    Set<String>? areas,
  }) async {
    final out = <Activity>[];
    for (final n in await _allNotes()) {
      if (n.deletedAt != null) continue;
      final Activity a;
      try {
        a = _decode(n);
      } on ActivityUnreadable {
        continue;
      }
      final t = a.start.utc;
      if (t.isBefore(from.toUtc()) || !t.isBefore(to.toUtc())) continue;
      if (areas != null && !areas.contains(a.area)) continue;
      out.add(a);
    }
    out.sort((x, y) => y.start.utc.compareTo(x.start.utc));
    return out;
  }

  @override
  Future<Activity?> getActivity(String id) async {
    final note = await _liveNote(id);
    return note == null ? null : _decode(note);
  }

  @override
  Future<Activity> saveActivity(Activity activity) async {
    if (activity.id.isEmpty) {
      throw ArgumentError.value(
        activity.id,
        'id',
        'a stored activity needs an id',
      );
    }
    // Whole seconds, UTC: the stored ISO string has no sub-second part, so
    // the returned activity must equal what a later read gives back.
    final n = _now();
    final saved = activity.copyWith(
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        n.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      ),
    );
    final content = jsonEncode(ActivityCodec.encode(saved));
    final subject = activitySubjectFor(saved.id);

    // getNoteByUuid also returns soft-deleted rows: restore and update that
    // note instead of creating a second one with a clashing uuid.
    final existing = await _notes.getNoteByUuid(saved.id);
    final catalogId = await _catalogId();
    if (existing != null && existing.catalogId != catalogId) {
      throw ActivityIdCollision(saved.id);
    }
    if (existing == null) {
      await _notes.createNote(
        HmmNoteCreate(
          subject: subject,
          catalogId: catalogId,
          content: content,
          uuid: saved.id,
        ),
      );
    } else {
      if (existing.deletedAt != null) await _notes.restoreNote(existing.id);
      await _notes.updateNote(
        existing.id,
        HmmNoteUpdate(subject: subject, content: content),
      );
    }
    return saved;
  }

  @override
  Future<void> deleteActivity(String id) async {
    final note = await _liveNote(id);
    if (note == null) return;
    await _notes.deleteNote(note.id);
  }

  @override
  Stream<void> changes() {
    late final StreamController<void> out;
    StreamSubscription<List<HmmNote>>? sub;
    Timer? retry;
    String? last;

    // The notes watch can fail or end, e.g. at start-up when the current
    // author is still in an error state: the error is passed on and the
    // watch is re-attached after [_changesRetryDelay], so the activity log never
    // goes silent for the rest of the session.
    void attach() {
      if (out.isClosed || !out.hasListener) return;
      void again() {
        sub = null;
        retry?.cancel();
        retry = Timer(_changesRetryDelay, attach);
      }

      sub = _notes.watchNotes().listen(
        (notes) async {
          final int catalogId;
          try {
            catalogId = await _catalogId();
          } catch (e, st) {
            // Never let it escape to the zone; subscribers log it and the
            // next notes change tries again.
            if (!out.isClosed) out.addError(e, st);
            return;
          }
          // Content is part of the key: stamps are whole seconds, so two
          // edits in one second must still emit.
          final key = [
            for (final n in notes)
              if (n.catalogId == catalogId)
                '${n.uuid}|${n.lastModifiedDate?.toIso8601String()}|'
                    '${n.content.hashCode}',
          ].join('\n');
          // The first snapshot is the baseline, not a change: a listener
          // that reloads on every emission (the activity list) would
          // otherwise loop. After a re-attach, a snapshot that differs from
          // the last one seen reports what changed during the gap.
          final first = last == null;
          if (key == last || out.isClosed) return;
          last = key;
          if (!first) out.add(null);
        },
        onError: (Object e, StackTrace st) {
          if (!out.isClosed) out.addError(e, st);
          unawaited(sub?.cancel());
          again();
        },
        onDone: again,
        cancelOnError: true,
      );
    }

    out = StreamController<void>(
      onListen: attach,
      onCancel: () {
        retry?.cancel();
        retry = null;
        return sub?.cancel();
      },
    );
    return out.stream;
  }
}
