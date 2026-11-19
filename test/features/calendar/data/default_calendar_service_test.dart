import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/calendar/contract/calendar_service.dart';
import 'package:hmm_console/features/calendar/data/default_calendar_service.dart';
import 'package:hmm_console/features/calendar/data/local_calendar_repository.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';

void main() {
  late HmmDatabase db;
  late LocalCalendarRepository repo;
  late DefaultCalendarService service;
  late LocalHmmNoteRepository notes;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    notes = LocalHmmNoteRepository(db, () async => author);
    repo = LocalCalendarRepository(notes, LocalNoteCatalogRepository(db));
    service = DefaultCalendarService(repo);
  });
  tearDown(() => db.close());

  const owner = EventOwner(subsystem: 'diabetes', noteUuid: 'n1');
  const other = EventOwner(subsystem: 'diabetes', noteUuid: 'n2');

  CalendarEventDraft draft({
    String? id,
    String title = 'Insulin',
    String? reminderBody,
    EventSource source = EventSource.subsystem,
    bool timeSensitive = true,
  }) => CalendarEventDraft(
    timeSensitive: timeSensitive,
    id: id,
    title: title,
    start: const FloatingTime(2027, 5, 10, 9, 0),
    reminders: const [Reminder(minutesBefore: 10)],
    reminderBody: reminderBody,
    source: source,
  );

  test(
    'creates with owner and subsystem source; second call updates',
    () async {
      final a = await service.upsertOwnedEvent(owner, draft());
      expect(a.owner, owner);
      expect(a.source, EventSource.subsystem);
      final b = await service.upsertOwnedEvent(
        owner,
        draft(id: a.id, title: 'Renamed'),
      );
      expect(b.id, a.id);
      final list = await service.ownedEvents(owner);
      expect(list, hasLength(1));
      expect(list.single.title, 'Renamed');
    },
  );

  test(
    'timeSensitive defaults on, is stored, and updates follow the draft',
    () async {
      expect(
        const CalendarEventDraft(
          title: 't',
          start: AllDay(2027, 1, 1),
        ).timeSensitive,
        isTrue,
      );
      final a = await service.upsertOwnedEvent(owner, draft());
      expect(a.timeSensitive, isTrue);
      final b = await service.upsertOwnedEvent(
        owner,
        draft(id: a.id, timeSensitive: false),
      );
      expect(b.timeSensitive, isFalse);
      expect((await repo.getEvent(a.id))!.timeSensitive, isFalse);
      final c = await service.upsertOwnedEvent(owner, draft(id: a.id));
      expect(c.timeSensitive, isTrue);
    },
  );

  test('assistant source is kept', () async {
    final a = await service.upsertOwnedEvent(
      owner,
      draft(source: EventSource.assistant),
    );
    expect(a.source, EventSource.assistant);
  });

  test('manual draft source becomes subsystem', () async {
    final a = await service.upsertOwnedEvent(
      owner,
      draft(source: EventSource.manual),
    );
    expect(a.source, EventSource.subsystem);
  });

  test('reminderBody round-trips and null removes it', () async {
    final a = await service.upsertOwnedEvent(
      owner,
      draft(reminderBody: 'Take'),
    );
    expect((await repo.getEvent(a.id))!.extraFields['reminderBody'], 'Take');
    final b = await service.upsertOwnedEvent(owner, draft(id: a.id));
    expect(
      (await repo.getEvent(b.id))!.extraFields.containsKey('reminderBody'),
      isFalse,
    );
  });

  test('update keeps occurrences, status and unknown extraFields', () async {
    final a = await service.upsertOwnedEvent(owner, draft(reminderBody: 'x'));
    await repo.saveEvent(
      (await repo.getEvent(a.id))!.copyWith(
        status: EventStatus.cancelled,
        extraFields: {...a.extraFields, 'future': 1, 'reminderBody': 'x'},
      ),
    );
    await repo.setOccurrence(
      a.id,
      const OccurrenceOverride(
        originalStart: FloatingTime(2027, 5, 10, 9, 0),
        status: OccurrenceStatus.done,
      ),
    );
    await service.upsertOwnedEvent(owner, draft(id: a.id, title: 'New'));
    final e = (await repo.getEvent(a.id))!;
    expect(e.title, 'New');
    expect(e.occurrences, hasLength(1));
    expect(e.status, EventStatus.cancelled);
    expect(e.extraFields['future'], 1);
  });

  test('draft id owned by another owner throws ArgumentError', () async {
    final a = await service.upsertOwnedEvent(owner, draft());
    expect(
      () => service.upsertOwnedEvent(other, draft(id: a.id)),
      throwsArgumentError,
    );
  });

  test('draft id that does not exist is created with that id', () async {
    final a = await service.upsertOwnedEvent(owner, draft(id: 'fixed-id'));
    expect(a.id, 'fixed-id');
  });

  test('removeOwnedEvents deletes only that owner', () async {
    await service.upsertOwnedEvent(owner, draft());
    await service.upsertOwnedEvent(other, draft());
    await service.removeOwnedEvents(owner);
    expect(await service.ownedEvents(owner), isEmpty);
    expect(await service.ownedEvents(other), hasLength(1));
  });

  test('a draft id of a soft-deleted owned event restores that note', () async {
    final first = await service.upsertOwnedEvent(owner, draft(id: 'ev1'));
    await repo.deleteEvent(first.id);
    final noteId = (await notes.getNoteByUuid('ev1'))!.id;

    final again = await service.upsertOwnedEvent(
      owner,
      draft(id: 'ev1', title: 'Insulin again'),
    );

    expect(again.id, 'ev1');
    final note = (await notes.getNoteByUuid('ev1'))!;
    expect(note.id, noteId);
    expect(note.deletedAt, isNull);
    expect((await repo.getEvent('ev1'))!.title, 'Insulin again');
    expect(await service.ownedEvents(owner), hasLength(1));
  });
}
