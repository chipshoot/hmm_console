import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/presentation/widgets/automobile_list_tile.dart';

import '../../helpers/gas_log_fixtures.dart';

void main() {
  // AutomobileListTile is now a ConsumerWidget that watches
  // attachmentResolverProvider. The fixture car has no primaryImage,
  // so the resolver provider is never read on the happy path — but
  // Riverpod still needs a ProviderScope ancestor or the widget
  // throws during build.
  Widget buildWidget({VoidCallback? onTap}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: AutomobileListTile(
            automobile: GasLogFixtures.automobile(),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  group('AutomobileListTile', () {
    testWidgets('displays automobile display name', (tester) async {
      await tester.pumpWidget(buildWidget());

      // displayName includes year, maker, brand, model
      expect(find.text('2023 Toyota Toyota Camry'), findsOneWidget);
    });

    testWidgets('displays plate number', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.textContaining('ABC 123'), findsOneWidget);
    });

    testWidgets('displays color', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.textContaining('Silver'), findsOneWidget);
    });

    testWidgets('displays mileage', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.textContaining('45230 mi'), findsOneWidget);
    });

    testWidgets('shows car icon in the fallback banner', (tester) async {
      // Fixture has no primaryImage, so the banner renders the
      // fallback (Icons.directions_car).
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });

    testWidgets('shows chevron trailing icon', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));

      // The tile no longer wraps a ListTile; the entire card is an
      // InkWell. Tap the AutomobileListTile root.
      await tester.tap(find.byType(AutomobileListTile));
      expect(tapped, isTrue);
    });
  });
}
