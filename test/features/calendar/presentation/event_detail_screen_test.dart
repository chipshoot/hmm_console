import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_calendar_repository.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

const _at = 'floating:2030-01-15T19:00';

CalendarEvent _ev(
  String id, {
  String? rrule = 'FREQ=DAILY',
  EventOwner? owner,
  bool draft = false,
  EventTime start = const FloatingTime(2030, 1, 13, 19, 0),
}) => CalendarEvent(
  id: id,
  title: 'Walk',
  start: start,
  end: start is FloatingTime
      ? FloatingTime(start.year, start.month, start.day, 20, 0)
      : null,
  rrule: rrule,
  owner: owner,
  draft: draft,
  notes: 'Bring water',
  reminders: const [Reminder(minutesBefore: 15)],
  updatedAt: DateTime.utc(2020),
);

Future<void> _mount(
  WidgetTester tester,
  FakeCalendarRepository repo, {
  String id = 'r',
  String? at = _at,
  DataMode mode = DataMode.local,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _Mode(mode)),
      localCalendarRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventDetailScreen(eventId: id, at: at),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('More actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows title, repeat in words, reminders and notes', (
    tester,
  ) async {
    await _mount(tester, FakeCalendarRepository()..seed(_ev('r')));
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    expect(find.text('15 minutes before'), findsOneWidget);
    expect(find.text('Bring water'), findsOneWidget);
    expect(find.textContaining('Jan 15, 2030'), findsOneWidget);
  });

  testWidgets('a repeating event opened at an occurrence offers Done and '
      'Skip with undo', (tester) async {
    final repo = FakeCalendarRepository()..seed(_ev('r'));
    await _mount(tester, repo);
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('occ:r:done'));
    final o = repo.events['r']!.occurrences.single;
    expect(o.originalStart, const FloatingTime(2030, 1, 15, 19, 0));
    expect(find.text('Marked done'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.log.last, 'save:r');
    expect(repo.events['r']!.occurrences, isEmpty);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('occ:r:skipped'));
  });

  testWidgets('iOS: Cupertino Done/Skip and a delete action sheet', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()..seed(_ev('r'));
    await _mount(tester, repo, platform: TargetPlatform.iOS);
    expect(find.byType(CupertinoButton), findsWidgets);
    expect(find.byType(FilledButton), findsNothing);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('Delete this one'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('occ:r:cancelled'));
  });

  testWidgets('a one-off has no Done/Skip', (tester) async {
    await _mount(
      tester,
      FakeCalendarRepository()..seed(_ev('r', rrule: null)),
      at: null,
    );
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Does not repeat'), findsOneWidget);
  });

  testWidgets('"From Diabetes" shows for the diabetes subsystem', (
    tester,
  ) async {
    await _mount(
      tester,
      FakeCalendarRepository()
        ..seed(_ev('r', owner: const EventOwner(subsystem: 'diabetes'))),
    );
    expect(find.text('From Diabetes'), findsOneWidget);
  });

  testWidgets('a draft shows Approve, which clears draft', (tester) async {
    final repo = FakeCalendarRepository()..seed(_ev('r', draft: true));
    await _mount(tester, repo);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(repo.events['r']!.draft, isFalse);
    expect(repo.events['r']!.notes, 'Bring water');
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('Delete series is undoable and undo restores the event', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()..seed(_ev('r'));
    final before = repo.events['r']!;
    await _mount(tester, repo);
    await _menu(tester, 'Delete series');
    expect(repo.log, contains('delete:r'));
    expect(find.text('Event deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.events['r'], before);
    expect(find.text('Event restored'), findsOneWidget);
  });

  testWidgets('Delete this one cancels the occurrence with its own messages', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()..seed(_ev('r'));
    await _mount(tester, repo);
    await _menu(tester, 'Delete this one');
    expect(repo.log, contains('occ:r:cancelled'));
    expect(find.text('Occurrence deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.events['r']!.occurrences, isEmpty);
    expect(find.text('Occurrence restored'), findsOneWidget);
  });

  testWidgets('Delete this and following sets UNTIL to the day before', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..seed(_ev('r', rrule: 'FREQ=DAILY;COUNT=30'));
    await _mount(tester, repo);
    await _menu(tester, 'Delete this and following');
    expect(repo.events['r']!.rrule, 'FREQ=DAILY;UNTIL=20300114');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.events['r']!.rrule, 'FREQ=DAILY;COUNT=30');
  });

  testWidgets('Delete this and following on the first one deletes the series', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()..seed(_ev('r'));
    await _mount(tester, repo, at: 'floating:2030-01-13T19:00');
    await _menu(tester, 'Delete this and following');
    expect(repo.log, contains('delete:r'));
  });

  testWidgets('a missing event shows not found', (tester) async {
    await _mount(tester, FakeCalendarRepository(), id: 'gone');
    expect(find.text('This event no longer exists.'), findsOneWidget);
  });

  testWidgets('an unreadable event shows the unreadable tile', (tester) async {
    await _mount(
      tester,
      FakeCalendarRepository(unreadable: ['bad']),
      id: 'bad',
    );
    expect(find.text('An event could not be read'), findsOneWidget);
    expect(find.text('This event no longer exists.'), findsNothing);
  });

  testWidgets('cloud API mode shows the friendly message', (tester) async {
    await _mount(
      tester,
      FakeCalendarRepository()..seed(_ev('r')),
      mode: DataMode.cloudApi,
    );
    expect(
      find.textContaining('available in Local and Cloud storage'),
      findsOneWidget,
    );
  });

  test('help for the event screen resolves in en and zh', () {
    for (final code in ['en', 'zh']) {
      final h = helpFor(
        HelpId.calendarEvent,
        lookupAppLocalizations(Locale(code)),
      );
      expect(h.title, isNotEmpty);
      expect(h.entries, isNotEmpty);
    }
  });
}
