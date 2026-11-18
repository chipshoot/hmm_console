import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/calendar/data/calendar_event_codec.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/catalog_labels.dart';
import 'package:hmm_console/features/notes/rendering/note_display.dart';
import 'package:hmm_console/features/notes/states/note_delete_policy.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import 'note_display_fixtures.dart';

const _calendar = 'Hmm.CalendarMan.Event';

HmmNote _eventNote(CalendarEvent e) => HmmNote(
  id: 50,
  uuid: e.id,
  subject: 'Event:${e.id}',
  authorId: 1,
  catalogId: 9,
  createDate: DateTime(2026, 11, 1),
  content: jsonEncode(CalendarEventCodec.encode(e)),
);

CalendarEvent _walk({
  String notes = '',
  String? rrule,
  EventTime start = const FloatingTime(2026, 11, 18, 19, 0),
}) => CalendarEvent(
  id: 'ev-1',
  title: 'Evening walk',
  notes: notes,
  start: start,
  rrule: rrule,
  updatedAt: DateTime.utc(2026, 11, 1),
);

Future<(NoteDisplayRegistry, AppLocalizations)> _setup(Locale locale) async {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return (
    c.read(noteDisplayRegistryProvider),
    await AppLocalizations.delegate.load(locale),
  );
}

void main() {
  const en = Locale('en');

  test('title comes from the event JSON, never Event:<uuid>', () async {
    final (r, l) = await _setup(en);
    final n = _eventNote(_walk());
    expect(r.hasEntry(_calendar), isTrue);
    expect(r.title(n, _calendar, l), 'Evening walk');
    final d = r.noteDisplay(n, _calendar, l);
    expect(d.title, 'Evening walk');
    expect(d.preview, isNot(contains('{')));
    expect(d.preview, isNot(contains('ev-1')));
  });

  test('preview shows the event notes when there are some', () async {
    final (r, l) = await _setup(en);
    final d = r.noteDisplay(
      _eventNote(_walk(notes: 'Round the park\nbring water')),
      _calendar,
      l,
    );
    expect(d.preview, 'Round the park');
  });

  test(
    'preview without notes shows the date, and Repeats for a series',
    () async {
      final (r, l) = await _setup(en);
      final once = r.noteDisplay(_eventNote(_walk()), _calendar, l);
      expect(once.preview, contains('2026'));
      expect(once.preview, isNot(contains('Repeats')));
      final daily = r.noteDisplay(
        _eventNote(
          _walk(rrule: 'FREQ=DAILY', start: const AllDay(2026, 11, 18)),
        ),
        _calendar,
        l,
      );
      expect(daily.preview, contains('Repeats'));
    },
  );

  test('unreadable event reads Event, never the id or raw JSON', () async {
    final (r, l) = await _setup(en);
    final d = r.noteDisplay(brokenNote('Event:ev-9', 9), _calendar, l);
    expect(d, (title: 'Event', preview: ''));
    final (_, zh) = await _setup(const Locale('zh'));
    expect(
      r.noteDisplay(brokenNote('Event:ev-9', 9), _calendar, zh).title,
      '日程',
    );
  });

  test('opening goes to the event screen', () async {
    final (r, _) = await _setup(en);
    final t = r.targetFor(_eventNote(_walk()), _calendar)!;
    expect(t.route, RouterNames.calendarEvent);
    expect(t.params, {'id': 'ev-1'});
    // Subject without an id falls back to the note uuid.
    final bare = HmmNote(
      id: 51,
      uuid: 'ev-2',
      subject: 'Event:',
      authorId: 1,
      createDate: DateTime(2026),
    );
    expect(r.targetFor(bare, _calendar)!.params, {'id': 'ev-2'});
  });

  test('delete is refused from Notes and points at the Calendar', () async {
    final l = await AppLocalizations.delegate.load(en);
    expect(canDeleteFromNotes(_eventNote(_walk()), _calendar), isFalse);
    expect(managePlaceFor(_calendar), NoteManagePlace.calendar);
    expect(managePlaceLabel(NoteManagePlace.calendar, l), 'Calendar');
  });
}
