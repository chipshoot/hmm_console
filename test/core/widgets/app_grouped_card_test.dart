import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_grouped_card.dart';

void main() {
  testWidgets('renders child inside a clipped filled card', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: const Scaffold(
        body: AppGroupedCard(child: Text('hello')),
      ),
    ));
    expect(find.text('hello'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppGroupedCard),
        matching: find.byType(ClipRRect),
      ),
      findsOneWidget,
    );
    final box = t.widget<ColoredBox>(find.descendant(
      of: find.byType(AppGroupedCard),
      matching: find.byType(ColoredBox),
    ));
    expect(box.color, AppColors.light.secondaryGroupedBackground);
  });
}
