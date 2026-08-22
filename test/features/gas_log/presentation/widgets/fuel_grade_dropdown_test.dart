import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/presentation/widgets/option_labels.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/features/gas_log/presentation/widgets/fuel_grade_dropdown.dart';

void main() {
  Widget buildWidget({
    String value = 'Regular',
    ValueChanged<String?>? onChanged,
  }) {
    return MaterialApp(
      // Required: the widget reads its label from AppLocalizations, and a
      // bare MaterialApp leaves that null so it throws while building.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: FuelGradeDropdown(
            value: value,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('FuelGradeDropdown', () {
    testWidgets('displays Fuel Grade label', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text('Fuel Grade'), findsOneWidget);
    });

    testWidgets('shows initial value', (tester) async {
      await tester.pumpWidget(buildWidget(value: 'Premium'));

      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('defaults to Regular for unknown value', (tester) async {
      await tester.pumpWidget(buildWidget(value: 'Unknown'));

      expect(find.text('Regular'), findsOneWidget);
    });

    testWidgets('shows all grade options when tapped', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Asserts the *labels*, which no longer equal the stored values:
      // 'MidGrade' now renders as "Mid-Grade". That gap is the point of the
      // change — the wire value stopped leaking into the UI — so the test
      // pins the labels rather than the raw list.
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      for (final grade in FuelGradeDropdown.grades) {
        expect(find.text(optionLabel(grade, l)), findsWidgets,
            reason: 'no option rendered for stored value "$grade"');
      }
    });

    testWidgets('translating the UI does not change what gets stored',
        (tester) async {
      // The reason this feature could not simply have `Text(g)` translated.
      // These strings are written into gas log records and sent to the API, so
      // if the Chinese build ever reported "普通" instead of "Regular" the
      // records would diverge by device language and every consumer comparing
      // against 'Regular' would stop matching.
      String? captured;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FuelGradeDropdown(
            value: 'Regular',
            onChanged: (v) => captured = v,
          ),
        ),
      ));

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Tapped by its Chinese label…
      await tester.tap(find.text('高级').last);
      await tester.pumpAndSettle();

      // …but the value handed to onChanged is the untranslated literal.
      expect(captured, 'Premium');
    });

    testWidgets('calls onChanged when selecting a grade', (tester) async {
      String? selected;
      await tester.pumpWidget(
        buildWidget(onChanged: (v) => selected = v),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Tap the last "Diesel" in the dropdown overlay
      await tester.tap(find.text('Diesel').last);
      await tester.pumpAndSettle();

      expect(selected, 'Diesel');
    });
  });
}
