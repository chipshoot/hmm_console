import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/presentation/widgets/gas_log_list_tile.dart';

import '../../helpers/gas_log_fixtures.dart';

void main() {
  Widget buildWidget({
    VoidCallback? onTap,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GasLogListTile(
          gasLog: GasLogFixtures.gasLog(),
          onTap: onTap,
          onDelete: onDelete,
        ),
      ),
    );
  }

  group('GasLogListTile', () {
    testWidgets('displays odometer reading', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.textContaining('45230'), findsOneWidget);
    });

    testWidgets('displays fuel amount', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.textContaining('42.3'), findsOneWidget);
    });

    testWidgets('displays total price', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.textContaining('164.55'), findsOneWidget);
    });

    testWidgets('displays station name', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.textContaining('Shell Station'), findsOneWidget);
    });

    testWidgets('displays fuel efficiency when > 0', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.textContaining('7.6 mi/gal'), findsOneWidget);
    });

    testWidgets('shows delete button when onDelete provided', (tester) async {
      await tester.pumpWidget(buildWidget(onDelete: () {}));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('hides delete button when onDelete is null', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));

      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });

    testWidgets('calls onDelete when delete button tapped', (tester) async {
      var deleted = false;
      await tester.pumpWidget(buildWidget(onDelete: () => deleted = true));

      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, isTrue);
    });
  });
}
