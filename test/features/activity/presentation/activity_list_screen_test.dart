import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/features/activity/contract/i_activity_repository.dart';
import 'package:hmm_console/features/activity/data/local_activity_repository.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/presentation/screens/activity_list_screen.dart';
import 'package:hmm_console/features/activity/states/activity_list_state.dart';
import 'package:hmm_console/features/activity/states/activity_providers.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../support/fake_activity_repository.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

/// Answers title lookups only.
class _Notes implements IHmmNoteRepository {
  _Notes(this.byUuid);
  final Map<String, HmmNote> byUuid;

  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => byUuid[uuid];

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

/// The device's "now": 21 Nov 2026, 10:00 local.
final _now = DateTime(2026, 11, 21, 10);

Activity _act(
  String id,
  String kind,
  OffsetDateTime start, {
  int minutes = 30,
  bool draft = false,
  List<ActivityLink> links = const [],
}) => Activity(
  id: id,
  kind: kind,
  start: start,
  durationMinutes: minutes,
  draft: draft,
  links: links,
  updatedAt: DateTime.utc(2026, 11, 21),
);

/// A start recorded in the device's own zone.
OffsetDateTime _local(int d, int h, [int m = 0]) =>
    OffsetDateTime.fromLocal(DateTime(2026, 11, d, h, m));

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  IActivityRepository? repo,
  DataMode mode = DataMode.local,
  IHmmNoteRepository? notes,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final container = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _Mode(mode)),
      if (repo != null) localActivityRepositoryProvider.overrideWithValue(repo),
      localHmmNoteRepositoryProvider.overrideWithValue(notes ?? _Notes({})),
      activityClockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ActivityListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The header text above [rowText]: the nearest header with a smaller y.
String _headerAbove(WidgetTester tester, String rowText) {
  final rowY = tester.getTopLeft(find.text(rowText)).dy;
  String? best;
  var bestY = double.negativeInfinity;
  for (final e in find.byKey(const Key('activity-day-header')).evaluate()) {
    final y = tester.getTopLeft(find.byWidget(e.widget)).dy;
    if (y < rowY && y > bestY) {
      bestY = y;
      best = (e.widget as Text).data;
    }
  }
  return best!;
}

void main() {
  testWidgets('empty state shows the message and a log button', (t) async {
    await _mount(t, repo: FakeActivityRepository());
    expect(find.text('No activities in this period.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log activity'), findsOneWidget);
  });

  testWidgets('rows group under Today, Yesterday and dated headers', (t) async {
    await _mount(
      t,
      repo: FakeActivityRepository([
        _act('a', 'health.walk', _local(21, 8)),
        _act('b', 'health.gym', _local(20, 7, 10), minutes: 45),
        _act('c', 'reading.reading', _local(18, 21), minutes: 40),
      ]),
    );
    expect(_headerAbove(t, 'Walk · 30 min'), 'Today');
    expect(_headerAbove(t, 'Gym · 45 min'), 'Yesterday');
    expect(_headerAbove(t, 'Reading · 40 min'), 'Wed, Nov 18');
    expect(find.text('7:10 AM'), findsOneWidget);
  });

  testWidgets('an entry stays under its own recorded date (travel)', (t) async {
    // 23:30 on 20 Nov at -05:00 is 21 Nov 04:30 UTC (12:30 in UTC+8): it
    // still belongs to 20 Nov, which is Yesterday for the 21 Nov clock.
    final start = OffsetDateTime.tryParse('2026-11-20T23:30:00-05:00')!;
    await _mount(
      t,
      repo: FakeActivityRepository([_act('a', 'health.walk', start)]),
    );
    expect(_headerAbove(t, 'Walk · 30 min'), 'Yesterday');
    expect(find.text('Today'), findsNothing);
    expect(find.text('11:30 PM'), findsOneWidget);
  });

  testWidgets('a +14:00 entry stays on its recorded date (date line)', (
    t,
  ) async {
    // 00:30 on 21 Nov at +14:00 is 20 Nov 10:30 UTC: 20 Nov in every zone
    // from -12:00 to +13:00, yet it was recorded on 21 Nov, so Today.
    final start = OffsetDateTime.tryParse('2026-11-21T00:30:00+14:00')!;
    await _mount(
      t,
      repo: FakeActivityRepository([_act('a', 'health.walk', start)]),
    );
    expect(_headerAbove(t, 'Walk · 30 min'), 'Today');
    expect(find.text('Yesterday'), findsNothing);
    expect(find.text('12:30 AM'), findsOneWidget);
  });

  testWidgets('area chips filter the rows', (t) async {
    await _mount(
      t,
      repo: FakeActivityRepository([
        _act('a', 'health.walk', _local(21, 8)),
        _act('b', 'reading.reading', _local(21, 9), minutes: 40),
        _act('c', 'development.coding', _local(21, 7), minutes: 50),
      ]),
    );
    expect(find.text('Walk · 30 min'), findsOneWidget);
    expect(find.text('Reading · 40 min'), findsOneWidget);
    expect(find.text('Coding · 50 min'), findsOneWidget);

    await t.tap(find.widgetWithText(ChoiceChip, 'Health'));
    await t.pumpAndSettle();
    expect(find.text('Walk · 30 min'), findsOneWidget);
    expect(find.text('Reading · 40 min'), findsNothing);
    expect(find.text('Coding · 50 min'), findsNothing);

    await t.tap(find.widgetWithText(ChoiceChip, 'Reading'));
    await t.pumpAndSettle();
    expect(find.text('Walk · 30 min'), findsNothing);
    expect(find.text('Reading · 40 min'), findsOneWidget);

    await t.tap(find.widgetWithText(ChoiceChip, 'Development'));
    await t.pumpAndSettle();
    expect(find.text('Coding · 50 min'), findsOneWidget);
    expect(find.text('Reading · 40 min'), findsNothing);

    await t.tap(find.widgetWithText(ChoiceChip, 'All'));
    await t.pumpAndSettle();
    expect(find.text('Walk · 30 min'), findsOneWidget);
    expect(find.text('Reading · 40 min'), findsOneWidget);
    expect(find.text('Coding · 50 min'), findsOneWidget);
  });

  testWidgets('Load earlier reaches another 30 days back', (t) async {
    await _mount(
      t,
      repo: FakeActivityRepository([
        _act('a', 'health.walk', _local(21, 8)),
        _act(
          'old',
          'health.gym',
          OffsetDateTime.fromLocal(DateTime(2026, 10, 12, 7)),
          minutes: 45,
        ),
      ]),
    );
    expect(find.text('Gym · 45 min'), findsNothing);
    await t.tap(find.text('Load earlier'));
    await t.pumpAndSettle();
    expect(find.text('Gym · 45 min'), findsOneWidget);
    expect(_headerAbove(t, 'Gym · 45 min'), 'Mon, Oct 12');
  });

  testWidgets('a draft shows the draft label', (t) async {
    await _mount(
      t,
      repo: FakeActivityRepository([
        _act('a', 'health.walk', _local(21, 8), draft: true),
      ]),
    );
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('a linked note title shows in the summary', (t) async {
    await _mount(
      t,
      repo: FakeActivityRepository([
        _act(
          'a',
          'reading.reading',
          _local(21, 9),
          minutes: 40,
          links: const [ActivityLink(noteUuid: 'book')],
        ),
        _act(
          'b',
          'reading.reading',
          _local(21, 8),
          minutes: 20,
          links: const [ActivityLink(noteUuid: 'gone')],
        ),
      ]),
      notes: _Notes({
        'book': HmmNote(
          id: 1,
          uuid: 'book',
          subject: 'Dune',
          authorId: 1,
          createDate: DateTime.utc(2026),
        ),
      }),
    );
    expect(find.text('Reading · 40 min · "Dune"'), findsOneWidget);
    expect(find.text('Reading · 20 min'), findsOneWidget);
  });

  testWidgets('long-press Delete, then Undo restores the same id', (t) async {
    final repo = FakeActivityRepository([
      _act('a', 'health.walk', _local(21, 8)),
    ]);
    await _mount(t, repo: repo);

    await t.longPress(find.text('Walk · 30 min'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(await repo.getActivity('a'), isNull);
    expect(find.text('Walk · 30 min'), findsNothing);
    expect(find.text('Activity deleted'), findsOneWidget);

    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    final back = await repo.getActivity('a');
    expect(back, isNotNull);
    expect(back!.kind, 'health.walk');
    expect(find.text('Walk · 30 min'), findsOneWidget);
    expect(find.text('Activity restored'), findsOneWidget);
  });

  testWidgets('an unreadable activity note does not break the list', (t) async {
    late HmmDatabase db;
    late IActivityRepository repo;
    late LocalHmmNoteRepository notes;
    await t.runAsync(() async {
      db = HmmDatabase(NativeDatabase.memory());
      final authorId = await db
          .into(db.authors)
          .insert(AuthorsCompanion.insert(accountName: 'tester'));
      final author = await (db.select(
        db.authors,
      )..where((a) => a.id.equals(authorId))).getSingle();
      notes = LocalHmmNoteRepository(db, () async => author);
      final catalogs = LocalNoteCatalogRepository(db);
      repo = LocalActivityRepository(notes, catalogs);
      await repo.saveActivity(_act('good', 'health.walk', _local(21, 8)));
      final catalog = await catalogs.getCatalogByName(activityCatalogName);
      await notes.createNote(
        HmmNoteCreate(
          subject: 'Activity:bad',
          catalogId: catalog!.id,
          content: '{bad',
          uuid: 'bad',
        ),
      );
    });
    addTearDown(() => t.runAsync(db.close));

    await t.runAsync(() => _mount(t, repo: repo, notes: notes));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
    expect(find.text('Walk · 30 min'), findsOneWidget);
    expect(find.text("Couldn't load activities."), findsNothing);
  });

  testWidgets('Cloud API mode shows the unavailable message', (t) async {
    await _mount(t, mode: DataMode.cloudApi);
    expect(
      find.textContaining("isn't available in Cloud API mode"),
      findsOneWidget,
    );
  });

  testWidgets('app bar has the activity help button', (t) async {
    await _mount(t, repo: FakeActivityRepository());
    final help = t.widget<HelpButton>(find.byType(HelpButton));
    expect(help.helpId, HelpId.activity);
  });

  testWidgets('iOS puts the add button in the app bar', (t) async {
    await _mount(
      t,
      repo: FakeActivityRepository(),
      platform: TargetPlatform.iOS,
    );
    expect(find.byTooltip('Log activity'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
