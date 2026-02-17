import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/presentation/widgets/date_picker_field.dart';
import 'package:intl/intl.dart';

void main() {
  Widget buildWidget({
    DateTime? selectedDate,
    ValueChanged<DateTime>? onDateChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: DatePickerField(
            selectedDate: selectedDate ?? DateTime(2026, 1, 15),
            onDateChanged: onDateChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('DatePickerField', () {
    testWidgets('displays Date label', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('displays formatted date', (tester) async {
      final date = DateTime(2026, 1, 15);
      await tester.pumpWidget(buildWidget(selectedDate: date));

      expect(find.text(DateFormat.yMMMd().format(date)), findsOneWidget);
    });

    testWidgets('shows calendar icon', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('opens date picker on tap', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // Date picker dialog should be showing
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
