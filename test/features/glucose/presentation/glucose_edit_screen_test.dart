import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/presentation/screens/glucose_edit_screen.dart';
import 'package:hmm_console/features/glucose/states/glucose_list_state.dart';
import 'package:hmm_console/features/glucose/states/glucose_providers.dart';
import 'package:hmm_console/features/glucose/states/glucose_settings_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../support/fake_glucose_repository.dart';

class _Unit extends GlucoseDisplayUnitNotifier {
  @override
  GlucoseUnit build() => GlucoseUnit.mmoll;
}

final _now = DateTime(2026, 11, 22, 10, 30);

Future<void> _mount(
  WidgetTester tester,
  FakeGlucoseRepository repo, {
  String? id,
}) async {
  final container = ProviderContainer(
    overrides: [
      glucoseRepositoryProvider.overrideWithValue(repo),
      glucoseClockProvider.overrideWithValue(() => _now),
      glucoseDisplayUnitProvider.overrideWith(_Unit.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GlucoseEditScreen(readingId: id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _saveEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.byKey(const Key('glucose-save')))
        .onPressed !=
    null;

GlucoseReading _imported() => GlucoseReading(
  id: 'imp',
  takenAt: OffsetDateTime(
    DateTime.utc(2026, 11, 20, 12, 41),
    const Duration(hours: -5),
  ),
  glucose: const GlucoseValue(112, GlucoseUnit.mgdl),
  source: GlucoseSource.appleHealth,
  appleHealth: const AppleHealthRef(
    sampleId: 'S1',
    sourceName: 'CONTOUR DIABETES',
  ),
);

void main() {
  testWidgets('new: unit defaults to display unit, Save needs a valid value', (
    tester,
  ) async {
    await _mount(tester, FakeGlucoseRepository());
    expect(
      tester
          .widget<SegmentedButton<GlucoseUnit>>(
            find.byKey(const Key('glucose-unit')),
          )
          .selected,
      {GlucoseUnit.mmoll},
    );
    expect(_saveEnabled(tester), isFalse);

    await tester.tap(find.text('mg/dL'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('glucose-value')), '650');
    await tester.pump();
    expect(find.textContaining('Enter a value from 20 to 600'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const Key('glucose-value')), '112');
    await tester.pump();
    expect(find.textContaining('Enter a value'), findsNothing);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('new: saves 6.2 mmol/L as manual at the device offset', (
    tester,
  ) async {
    final repo = FakeGlucoseRepository();
    await _mount(tester, repo);
    await tester.enterText(find.byKey(const Key('glucose-value')), '6.2');
    await tester.pump();
    await tester.tap(find.byKey(const Key('glucose-tag-fasting')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('glucose-tag-fasting')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('glucose-save')));
    await tester.pumpAndSettle();

    final all = await repo.readingsBetween(
      DateTime.utc(2000),
      DateTime.utc(2100),
    );
    expect(all, hasLength(1));
    expect(all.single.glucose, const GlucoseValue(6.2, GlucoseUnit.mmoll));
    expect(all.single.source, GlucoseSource.manual);
    expect(all.single.context, isNull);
    expect(all.single.takenAt, OffsetDateTime.fromLocal(_now));
  });

  testWidgets('imported: value and time are read-only, tag and notes save', (
    tester,
  ) async {
    final o = _imported();
    final repo = FakeGlucoseRepository([o]);
    await _mount(tester, repo, id: 'imp');
    expect(find.text('From Apple Health · CONTOUR DIABETES'), findsOneWidget);
    expect(find.byKey(const Key('glucose-value')), findsNothing);
    expect(find.byKey(const Key('glucose-date')), findsNothing);
    expect(find.byKey(const Key('glucose-value-readonly')), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('glucose-tag-afterMeal')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('glucose-notes')),
      'late lunch',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('glucose-save')));
    await tester.pumpAndSettle();

    final r = (await repo.getReading('imp'))!;
    expect(r.context, GlucoseContext.afterMeal);
    expect(r.notes, 'late lunch');
    expect(r.glucose, o.glucose);
    expect(r.takenAt, o.takenAt);
    expect(r.appleHealth, o.appleHealth);
  });

  testWidgets('has a help button', (tester) async {
    await _mount(tester, FakeGlucoseRepository());
    expect(find.byType(HelpButton), findsOneWidget);
  });
}
