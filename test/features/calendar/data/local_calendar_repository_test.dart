import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/calendar/contract/calendar_errors.dart';
import 'package:hmm_console/features/calendar/data/local_calendar_repository.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';

import '../contract/calendar_repository_contract.dart';

late HmmDatabase _db;
late LocalHmmNoteRepository _notes;
late LocalNoteCatalogRepository _catalogs;

Future<LocalCalendarRepository> _make() async {
  _db = HmmDatabase(NativeDatabase.memory());
  final authorId = await _db
      .into(_db.authors)
      .insert(AuthorsCompanion.insert(accountName: 'tester'));
  final author = await (_db.select(
    _db.authors,
  )..where((a) => a.id.equals(authorId))).getSingle();
  _notes = LocalHmmNoteRepository(_db, () async => author);
  _catalogs = LocalNoteCatalogRepository(_db);
  return LocalCalendarRepository(_notes, _catalogs);
}

/// Delegates to [inner]; `getOrCreateCatalog` throws while [failCreate] is
/// positive (counting down), and every call throws when [failAll].
class _FlakyCatalogs implements INoteCatalogRepository {
  _FlakyCatalogs(this.inner);

  final INoteCatalogRepository inner;
  int failCreate = 0;
  bool failAll = false;

  void _check() {
    if (failAll) throw StateError('catalog store down');
  }

  @override
  Future<NoteCatalog> getOrCreateCatalog(String name, String schema) async {
    _check();
    if (failCreate > 0) {
      failCreate--;
      // What the losing side of a first-run race sees.
      await inner.getOrCreateCatalog(name, schema);
      throw StateError('UNIQUE constraint failed: note_catalogs.name');
    }
    return inner.getOrCreateCatalog(name, schema);
  }

  @override
  Future<NoteCatalog?> getCatalogByName(String name) async {
    _check();
    return inner.getCatalogByName(name);
  }

  @override
  Future<List<NoteCatalog>> getCatalogs() => inner.getCatalogs();
  @override
  Future<NoteCatalog?> getCatalogById(int id) => inner.getCatalogById(id);
  @override
  Future<NoteCatalog> createCatalog(NoteCatalogsCompanion c) =>
      inner.createCatalog(c);
  @override
  Future<NoteCatalog> updateCatalog(int id, NoteCatalogsCompanion c) =>
      inner.updateCatalog(id, c);
  @override
  Stream<List<NoteCatalog>> watchCatalogs() => inner.watchCatalogs();
}

CalendarEvent _ev(String id, {String title = 'T'}) => CalendarEvent(
  id: id,
  title: title,
  start: const FloatingTime(2027, 5, 10, 9, 0),
  updatedAt: DateTime.utc(2020),
);

void main() {
  runCalendarRepositoryContract(() async {
    final repo = await _make();
    addTearDown(() => _db.close());
    return repo;
  });

  group('LocalCalendarRepository', () {
    late LocalCalendarRepository repo;
    setUp(() async => repo = await _make());
    tearDown(() => _db.close());

    Future<int> catalogId() async =>
        (await _catalogs.getCatalogByName(calendarCatalogName))!.id;

    test('note subject is Event:<id>, uuid is the id, schema is set', () async {
      await repo.saveEvent(_ev('abc'));
      final note = (await _notes.getNoteByUuid('abc'))!;
      expect(note.subject, 'Event:abc');
      expect(note.uuid, 'abc');
      final cat = (await _catalogs.getCatalogByName('Hmm.CalendarMan.Event'))!;
      expect(note.catalogId, cat.id);
      expect(jsonDecode(cat.schema), {'type': 'calendarEvent'});
    });

    test(
      'an id taken by a note of another catalog is refused, note untouched',
      () async {
        final other = await _catalogs.getOrCreateCatalog('Hmm.Other', '{}');
        await _notes.createNote(
          HmmNoteCreate(
            subject: 'Mine',
            catalogId: other.id,
            content: 'keep me',
            uuid: 'shared',
          ),
        );
        final before = (await _notes.getNoteByUuid('shared'))!;
        await _notes.deleteNote(before.id); // soft-deleted is still refused

        await expectLater(
          repo.saveEvent(_ev('shared')),
          throwsA(isA<CalendarIdCollision>()),
        );

        final after = (await _notes.getNoteByUuid('shared'))!;
        expect(after.subject, 'Mine');
        expect(after.content, 'keep me');
        expect(after.catalogId, other.id);
        expect(after.deletedAt, isNotNull);
        expect(await repo.getEvent('shared'), isNull);
      },
    );

    test(
      'getEventIncludingDeleted returns a soft-deleted event with its reminders',
      () async {
        await repo.saveEvent(
          _ev('d1').copyWith(reminders: const [Reminder(minutesBefore: 60)]),
        );
        await repo.deleteEvent('d1');

        final e = await repo.getEventIncludingDeleted('d1');

        expect(e, isNotNull);
        expect(e!.reminders.single.minutesBefore, 60);
        expect(await repo.getEventIncludingDeleted('missing'), isNull);
      },
    );

    test('getEvent still returns null for a soft-deleted event', () async {
      await repo.saveEvent(_ev('d2'));
      await repo.deleteEvent('d2');
      expect(await repo.getEvent('d2'), isNull);
    });

    test('eventsOwnedBySubsystems returns only matching live events', () async {
      EventOwner o(String s) => EventOwner(subsystem: s, noteUuid: 'n-$s');
      await repo.saveEvent(_ev('o1').copyWith(owner: o('contacts')));
      await repo.saveEvent(_ev('o2').copyWith(owner: o('insurance')));
      await repo.saveEvent(_ev('o3').copyWith(owner: o('diabetes')));
      await repo.saveEvent(_ev('o4').copyWith(owner: o('contacts')));
      await repo.deleteEvent('o4');
      await repo.saveEvent(_ev('o5'));

      final got = await repo.eventsOwnedBySubsystems({'contacts', 'insurance'});

      expect(got.map((e) => e.id).toSet(), {'o1', 'o2'});
      expect(await repo.eventsOwnedBySubsystems({}), isEmpty);
    });

    test(
      'a deleted uuid saved again restores the same note (Review Focus 2)',
      () async {
        await repo.saveEvent(_ev('e1', title: 'Old'));
        final firstId = (await _notes.getNoteByUuid('e1'))!.id;
        await repo.deleteEvent('e1');
        expect(await repo.getEvent('e1'), isNull);

        await repo.saveEvent(_ev('e1', title: 'New'));

        final note = (await _notes.getNoteByUuid('e1'))!;
        expect(note.id, firstId);
        expect(note.deletedAt, isNull);
        expect((await repo.getEvent('e1'))!.title, 'New');
        final all = await _notes.getNotes(
          catalogId: await catalogId(),
          includeDeleted: true,
          pageSize: 100,
        );
        expect(all.items.where((n) => n.uuid == 'e1'), hasLength(1));
      },
    );

    test(
      'changes() emits when a calendar note is inserted directly (sync pull)',
      () async {
        var n = 0;
        final sub = repo.changes().listen((_) => n++);
        final cid = (await _catalogs.getOrCreateCatalog(
          calendarCatalogName,
          '{"type":"calendarEvent"}',
        )).id;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final before = n;
        await _notes.createNote(
          HmmNoteCreate(
            subject: 'Event:pulled',
            catalogId: cid,
            uuid: 'pulled',
            content: '{}',
          ),
        );
        for (var i = 0; i < 40 && n <= before; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        final emitted = n;
        await sub.cancel();
        expect(emitted, greaterThan(before));
      },
    );

    test(
      'undecodable content throws on getEvent; eventsBetween skips it',
      () async {
        await repo.saveEvent(_ev('good'));
        final cid = await catalogId();
        await _notes.createNote(
          HmmNoteCreate(
            subject: 'Event:bad',
            catalogId: cid,
            uuid: 'bad',
            content: 'not json at all',
          ),
        );
        await expectLater(
          repo.getEvent('bad'),
          throwsA(isA<CalendarEventUnreadable>()),
        );
        final got = await repo.eventsBetween(
          DateTime(2027, 5, 1),
          DateTime(2027, 6, 1),
        );
        expect(got.map((e) => e.id), ['good']);

        final all = await repo.readAll();
        expect(all, hasLength(2));
        expect(all.whereType<CalendarEventReadable>(), hasLength(1));
        final bad = all.whereType<CalendarEventUnreadableResult>().single;
        expect(bad.id, 'bad');
      },
    );

    test('saveEvent over an unreadable note overwrites it in place', () async {
      final cid = (await _catalogs.getOrCreateCatalog(
        calendarCatalogName,
        '{"type":"calendarEvent"}',
      )).id;
      await _notes.createNote(
        HmmNoteCreate(
          subject: 'Event:bad',
          catalogId: cid,
          uuid: 'bad',
          content: '[]',
        ),
      );
      await repo.saveEvent(_ev('bad'));
      expect((await repo.getEvent('bad'))!.title, 'T');
    });
  });

  group('catalog failures', () {
    late _FlakyCatalogs flaky;
    late LocalCalendarRepository repo;
    setUp(() async {
      await _make();
      flaky = _FlakyCatalogs(_catalogs);
      repo = LocalCalendarRepository(_notes, flaky);
    });
    tearDown(() => _db.close());

    test('losing the first-run catalog race re-reads the winner', () async {
      flaky.failCreate = 1;
      await repo.saveEvent(_ev('r1'));
      expect((await repo.getEvent('r1'))!.id, 'r1');
    });

    test(
      'a catalog error in changes() reaches the stream, not the zone',
      () async {
        final errors = <Object>[];
        final events = <void>[];
        final sub = repo.changes().listen(events.add, onError: errors.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();
        flaky.failAll = true;
        await _notes.createNote(
          HmmNoteCreate(subject: 'x', catalogId: 1, content: '', uuid: 'z'),
        );
        await pumpEventQueue();
        expect(errors, isNotEmpty);
        expect(errors.first, isA<StateError>());

        // The stream keeps working once the store recovers.
        flaky.failAll = false;
        events.clear();
        await repo.saveEvent(_ev('after'));
        await pumpEventQueue();
        expect(events, isNotEmpty);
      },
    );
  });

  group('changes() reports changes, not the initial snapshot', () {
    // A listener that reloads on every emission (the calendar screen) must
    // not loop: subscribing alone emits nothing.
    test('subscribing without any write emits nothing', () async {
      final repo = await _make();
      await repo.saveEvent(_ev('existing'));
      var n = 0;
      final sub = repo.changes().listen((_) => n++);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(n, 0);
      await repo.saveEvent(_ev('new'));
      for (var i = 0; i < 40 && n == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(n, greaterThan(0));
    });
  });

  group('changes() survives an early notes-watch failure', () {
    // On device the first watchNotes() can fail at start-up (the current
    // author provider is still in an error state); the watch then ends, and
    // the calendar must subscribe again rather than go silent for good.
    test(
      're-subscribes after the notes watch errors, then emits on saves',
      () async {
        final db = HmmDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final authorId = await db
            .into(db.authors)
            .insert(AuthorsCompanion.insert(accountName: 'tester'));
        final author = await (db.select(
          db.authors,
        )..where((a) => a.id.equals(authorId))).getSingle();
        var failFirst = true;
        final notes = LocalHmmNoteRepository(db, () async {
          if (failFirst) {
            failFirst = false;
            throw StateError('Tried to use a provider that is in error state');
          }
          return author;
        });
        final repo = LocalCalendarRepository(
          notes,
          LocalNoteCatalogRepository(db),
          changesRetryDelay: const Duration(milliseconds: 20),
        );
        final errors = <Object>[];
        var n = 0;
        final sub = repo.changes().listen((_) => n++, onError: errors.add);
        addTearDown(sub.cancel);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final before = n;
        await repo.saveEvent(_ev('after-failure'));
        for (var i = 0; i < 40 && n <= before; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect(n, greaterThan(before));
      },
    );
  });
}
