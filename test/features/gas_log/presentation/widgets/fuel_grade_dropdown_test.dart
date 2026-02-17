import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/presentation/widgets/fuel_grade_dropdown.dart';

void main() {
  Widget buildWidget({
    String value = 'Regular',
    ValueChanged<String?>? onChanged,
  }) {
    return MaterialApp(
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

      for (final grade in FuelGradeDropdown.grades) {
        expect(find.text(grade), findsWidgets);
      }
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
