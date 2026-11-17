import 'dart:async';
import 'dart:convert';

import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/local/local_hmm_note_repository.dart';
import '../../../core/data/local/local_note_catalog_repository.dart';
import '../../notes/data/models/hmm_note.dart';
import '../contract/calendar_errors.dart';
import '../contract/i_calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/recurrence_expander.dart';
import 'calendar_event_codec.dart';

const calendarCatalogName = 'Hmm.CalendarMan.Event';
const _catalogSchema = '{"type":"calendarEvent"}';

/// The subject is identity: the title lives only in the JSON.
String calendarSubjectFor(String eventId) => 'Event:$eventId';

/// One stored event, or the id of a note that could not be decoded.
sealed class CalendarEventReadResult {
  const CalendarEventReadResult();
}

class CalendarEventReadable extends CalendarEventReadResult {
  const CalendarEventReadable(this.event);
  final CalendarEvent event;
}

class CalendarEventUnreadableResult extends CalendarEventReadResult {
  const CalendarEventUnreadableResult(this.id);
  final String id;
}

/// Stores each event as the JSON content of a note in the
/// `Hmm.CalendarMan.Event` catalog; the note uuid is the event id.
class LocalCalendarRepository implements ICalendarRepository {
  LocalCalendarRepository(
    this._notes,
    this._catalogs, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final IHmmNoteRepository _notes;
  final INoteCatalogRepository _catalogs;
  final DateTime Function() _now;

  static const _pageSize = 100;

  Future<int> _catalogId() async => (await _catalogs.getOrCreateCatalog(
    calendarCatalogName,
    _catalogSchema,
  )).id;

  CalendarEvent _decode(HmmNote note) {
    try {
      final json = jsonDecode(note.content ?? '');
      if (json is! Map) throw CalendarEventUnreadable(note.uuid);
      return CalendarEventCodec.decode(note.uuid, json.cast<String, Object?>());
    } on CalendarEventUnreadable {
      rethrow;
    } catch (_) {
      throw CalendarEventUnreadable(note.uuid);
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

  /// Every readable or unreadable event, so screens can skip bad notes.
  Future<List<CalendarEventReadResult>> readAll() async => [
    for (final n in await _allNotes())
      () {
        try {
          return CalendarEventReadable(_decode(n));
        } on CalendarEventUnreadable {
          return CalendarEventUnreadableResult(n.uuid);
        }
      }(),
  ];

  Future<List<CalendarEvent>> _readable() async => [
    for (final r in await readAll())
      if (r is CalendarEventReadable) r.event,
  ];

  @override
  Future<List<CalendarEvent>> eventsBetween(DateTime from, DateTime to) async =>
      [
        for (final e in await _readable())
          if (expandOccurrences(e, from, to).isNotEmpty) e,
      ];

  @override
  Future<CalendarEvent?> getEvent(String id) async {
    final note = await _liveNote(id);
    return note == null ? null : _decode(note);
  }

  @override
  Future<List<CalendarEvent>> eventsOwnedBy(EventOwner owner) async => [
    for (final e in await _readable())
      if (e.owner?.subsystem == owner.subsystem &&
          e.owner?.noteUuid == owner.noteUuid)
        e,
  ];

  @override
  Future<CalendarEvent> saveEvent(CalendarEvent event) async {
    if (event.id.isEmpty) {
      throw ArgumentError.value(event.id, 'id', 'a stored event needs an id');
    }
    // Whole seconds: the stored ISO string has no sub-second part, so the
    // returned event must equal what a later read gives back.
    final n = _now();
    final saved = event.copyWith(
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        n.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: n.isUtc,
      ),
    );
    final content = jsonEncode(CalendarEventCodec.encode(saved));
    final subject = calendarSubjectFor(saved.id);

    // getNoteByUuid also returns soft-deleted rows: restore and update that
    // note instead of creating a second one with a clashing uuid.
    final existing = await _notes.getNoteByUuid(saved.id);
    if (existing == null) {
      await _notes.createNote(
        HmmNoteCreate(
          subject: subject,
          catalogId: await _catalogId(),
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
  Future<void> deleteEvent(String id) async {
    final note = await _liveNote(id);
    if (note == null) return;
    await _notes.deleteNote(note.id);
  }

  @override
  Future<CalendarEvent> setOccurrence(
    String eventId,
    OccurrenceOverride o,
  ) async {
    final event = await getEvent(eventId);
    if (event == null) throw CalendarEventNotFound(eventId);
    final key = o.originalStart.wireKey;
    final list = [...event.occurrences];
    final i = list.indexWhere((x) => x.originalStart.wireKey == key);
    if (i >= 0) {
      list[i] = o;
    } else {
      list.add(o);
    }
    return saveEvent(event.copyWith(occurrences: list));
  }

  @override
  Stream<void> changes() {
    late final StreamController<void> out;
    StreamSubscription<List<HmmNote>>? sub;
    String? last;
    out = StreamController<void>(
      onListen: () {
        sub = _notes.watchNotes().listen((notes) async {
          final catalogId = await _catalogId();
          // Content is part of the key: stamps are whole seconds, so two
          // edits in one second must still emit.
          final key = [
            for (final n in notes)
              if (n.catalogId == catalogId)
                '${n.uuid}|${n.lastModifiedDate?.toIso8601String()}|'
                    '${n.content.hashCode}',
          ].join('\n');
          if (key == last || out.isClosed) return;
          last = key;
          out.add(null);
        }, onError: out.addError);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }
}
