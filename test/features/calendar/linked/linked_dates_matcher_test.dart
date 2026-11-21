import 'dart:ui';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/data/local_calendar_repository.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/linked_event.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_rule.dart';
import 'package:hmm_console/features/calendar/linked/linked_dates_matcher.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

Future<LocalCalendarRepository> _make() async {
  final db = HmmDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final authorId = await db
      .into(db.authors)
      .insert(AuthorsCompanion.insert(accountName: 'tester'));
  final author = await (db.select(
    db.authors,
  )..where((a) => a.id.equals(authorId))).getSingle();
  return LocalCalendarRepository(
    LocalHmmNoteRepository(db, () async => author),
    LocalNoteCatalogRepository(db),
  );
}

/// Throws on reads of [badId], like an unreadable stored note.
class _Flaky extends LocalCalendarRepository {
  _Flaky(super.notes, super.catalogs, this.badId);
  final String badId;
  @override
  Future<CalendarEvent?> getEvent(String id) {
    if (id == badId) throw const FormatException('unreadable');
    return super.getEvent(id);
  }
}

Future<_Flaky> _makeFlaky(String badId) async {
  final db = HmmDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final authorId = await db
      .into(db.authors)
      .insert(AuthorsCompanion.insert(accountName: 'tester'));
  final author = await (db.select(
    db.authors,
  )..where((a) => a.id.equals(authorId))).getSingle();
  return _Flaky(
    LocalHmmNoteRepository(db, () async => author),
    LocalNoteCatalogRepository(db),
    badId,
  );
}

final _en = lookupAppLocalizations(const Locale('en'));
final _zh = lookupAppLocalizations(const Locale('zh'));
const _subs = {'driverLicence', 'contacts'};

DatedItem _licence([AllDay date = const AllDay(2027, 3, 14)]) => DatedItem(
  key: 'licence:expiry',
  kind: LinkedKind.licenceExpiry,
  args: const {},
  date: date,
  owner: const EventOwner(subsystem: 'driverLicence', noteUuid: 'self'),
);

DatedItem _birthday() => DatedItem(
  key: 'contact:c1:birthday',
  kind: LinkedKind.birthday,
  args: const {'name': 'Ann'},
  date: const AllDay(2000, 2, 29),
  repeat: RecurrenceRule.gregorianYearlyBackward(),
  owner: const EventOwner(subsystem: 'contacts', noteUuid: 'c1'),
);

void main() {
  // Several in-memory databases per test is intended here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late LocalCalendarRepository repo;
  late LinkedDatesMatcher matcher;
  final id = linkedEventId('licence:expiry');

  setUp(() async {
    repo = await _make();
    matcher = LinkedDatesMatcher(repo, l: _en);
  });

  Future<MatchResult> run(List<DatedItem> w, [LinkedDatesMatcher? m]) =>
      (m ?? matcher).apply(wanted: w, subsystems: _subs);

  test(
    'creates a licence event with the 30-day reminder and Time Sensitive',
    () async {
      expect(await run([_licence()]), const MatchResult(1, 0, 0));
      final e = (await repo.getEvent(id))!;
      expect(e.reminders, [const Reminder(minutesBefore: 43200)]);
      expect(e.start, const AllDay(2027, 3, 14));
      expect(e.timeSensitive, isTrue);
      expect(e.source, EventSource.subsystem);
      expect(e.title, _en.calendarLinkedLicenceExpiry);
    },
  );

  test('second run with the same input writes nothing', () async {
    await run([_licence()]);
    final before = (await repo.getEvent(id))!.updatedAt;
    expect(await run([_licence()]), const MatchResult(0, 0, 0));
    expect((await repo.getEvent(id))!.updatedAt, before);
  });

  test("a moved date keeps the owner's reminders", () async {
    await run([_licence()]);
    final e = (await repo.getEvent(id))!;
    await repo.saveEvent(
      e.copyWith(reminders: const [Reminder(minutesBefore: 1440)]),
    );
    expect(
      await run([_licence(const AllDay(2027, 6, 1))]),
      const MatchResult(0, 1, 0),
    );
    final moved = (await repo.getEvent(id))!;
    expect(moved.reminders, [const Reminder(minutesBefore: 1440)]);
    expect(moved.start, const AllDay(2027, 6, 1));
  });

  test('two devices converge on one event', () async {
    final other = await _make();
    await run([_licence(), _birthday()]);
    await LinkedDatesMatcher(
      other,
      l: _en,
    ).apply(wanted: [_licence(), _birthday()], subsystems: _subs);
    for (final k in ['licence:expiry', 'contact:c1:birthday']) {
      final a = (await repo.getEvent(linkedEventId(k)))!;
      final b = (await other.getEvent(linkedEventId(k)))!;
      expect(
        a.copyWith(updatedAt: DateTime(2000)),
        b.copyWith(updatedAt: DateTime(2000)),
      );
    }
  });

  test('language change does not rewrite', () async {
    await run([_licence()]);
    expect(
      await run([_licence()], LinkedDatesMatcher(repo, l: _zh)),
      const MatchResult(0, 0, 0),
    );
    expect((await repo.getEvent(id))!.title, _en.calendarLinkedLicenceExpiry);
  });

  test(
    'removed item is deleted; a non-linked event of the same subsystem is kept',
    () async {
      await run([_licence()]);
      await repo.saveEvent(
        CalendarEvent(
          id: 'manual-1',
          title: 'Mine',
          start: const AllDay(2027, 1, 1),
          updatedAt: DateTime.now(),
          owner: const EventOwner(subsystem: 'driverLicence', noteUuid: 'x'),
        ),
      );
      expect(await run([]), const MatchResult(0, 0, 1));
      expect(await repo.getEvent(id), isNull);
      expect(await repo.getEvent('manual-1'), isNotNull);
    },
  );

  test('coming back keeps reminders and done marks', () async {
    await run([_licence()]);
    final e = (await repo.getEvent(id))!;
    await repo.saveEvent(
      e.copyWith(reminders: const [Reminder(minutesBefore: 1440)]),
    );
    await repo.setOccurrence(
      id,
      const OccurrenceOverride(
        originalStart: AllDay(2027, 3, 14),
        status: OccurrenceStatus.done,
      ),
    );
    await run([]);
    expect(await repo.getEvent(id), isNull);
    expect(await run([_licence()]), const MatchResult(1, 0, 0));
    final back = (await repo.getEvent(id))!;
    expect(back.reminders, [const Reminder(minutesBefore: 1440)]);
    expect(back.occurrences.single.status, OccurrenceStatus.done);
  });

  test('birthday gets its rule and the on-the-day reminder', () async {
    await run([_birthday()]);
    final e = (await repo.getEvent(linkedEventId('contact:c1:birthday')))!;
    expect(e.rrule, RecurrenceRule.gregorianYearlyBackward().format());
    expect(e.reminders, [const Reminder(minutesBefore: 0)]);
    expect(e.title, _en.calendarLinkedBirthday('Ann'));
    expect(linkedInfoOf(e)!.kind, LinkedKind.birthday);
  });

  test('changed args update the stored title and count as updated', () async {
    await run([_birthday()]);
    final renamed = DatedItem(
      key: 'contact:c1:birthday',
      kind: LinkedKind.birthday,
      args: const {'name': 'Anna'},
      date: const AllDay(2000, 2, 29),
      repeat: RecurrenceRule.gregorianYearlyBackward(),
      owner: const EventOwner(subsystem: 'contacts', noteUuid: 'c1'),
    );
    expect(await run([renamed]), const MatchResult(0, 1, 0));
    final e = (await repo.getEvent(linkedEventId('contact:c1:birthday')))!;
    expect(e.title, _en.calendarLinkedBirthday('Anna'));
  });

  test('a linked event of a subsystem outside the scope survives', () async {
    await run([_licence()]);
    final r = await matcher.apply(wanted: [], subsystems: {'contacts'});
    expect(r, const MatchResult(0, 0, 0));
    expect(await repo.getEvent(id), isNotNull);
  });

  test('duplicate keys: the first wins', () async {
    final r = await run([_licence(), _licence(const AllDay(2030, 1, 1))]);
    expect(r, const MatchResult(1, 0, 0));
    expect((await repo.getEvent(id))!.start, const AllDay(2027, 3, 14));
  });

  test('a restored event keeps Time Sensitive off and its notes', () async {
    await run([_licence()]);
    final e = (await repo.getEvent(id))!;
    await repo.saveEvent(e.copyWith(timeSensitive: false, notes: 'my note'));
    await run([]);
    await run([_licence()]);
    final back = (await repo.getEvent(id))!;
    expect(back.timeSensitive, isFalse);
    expect(back.notes, 'my note');
  });

  test('a second run after creating a birthday writes nothing', () async {
    await run([_birthday()]);
    expect(await run([_birthday()]), const MatchResult(0, 0, 0));
  });

  test(
    'one failing item does not stop the others and skips removals',
    () async {
      final flaky = await _makeFlaky(linkedEventId('contact:c1:birthday'));
      final m = LinkedDatesMatcher(flaky, l: _en);
      // A linked event that is no longer wanted.
      await m.apply(
        wanted: [
          DatedItem(
            key: 'contact:c9:birthday',
            kind: LinkedKind.birthday,
            args: const {'name': 'Old'},
            date: const AllDay(1990, 1, 1),
            owner: const EventOwner(subsystem: 'contacts', noteUuid: 'c9'),
          ),
        ],
        subsystems: _subs,
      );
      final r = await m.apply(
        wanted: [_birthday(), _licence()],
        subsystems: _subs,
      );
      expect(r, const MatchResult(1, 0, 0));
      expect(await flaky.getEvent(id), isNotNull);
      expect(
        await flaky.getEvent(linkedEventId('contact:c9:birthday')),
        isNotNull,
      );
    },
  );

  test('removals: false keeps unwanted linked events', () async {
    await run([_licence()]);
    final r = await matcher.apply(
      wanted: [],
      subsystems: _subs,
      removals: false,
    );
    expect(r, const MatchResult(0, 0, 0));
    expect(await repo.getEvent(id), isNotNull);
  });

  test('an update keeps the stored owner extra fields and settles', () async {
    await run([_licence()]);
    final e = (await repo.getEvent(id))!;
    await repo.saveEvent(
      e.copyWith(
        owner: const EventOwner(
          subsystem: 'driverLicence',
          noteUuid: 'self',
          extraFields: {'future': 1},
        ),
      ),
    );
    expect(
      await run([_licence(const AllDay(2027, 6, 1))]),
      const MatchResult(0, 1, 0),
    );
    expect((await repo.getEvent(id))!.owner!.extraFields, {'future': 1});
    expect(
      await run([_licence(const AllDay(2027, 6, 1))]),
      const MatchResult(0, 0, 0),
    );
  });
}
