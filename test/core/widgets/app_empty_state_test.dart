import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_empty_state.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders icon and message', (t) async {
    await t.pumpWidget(_host(const AppEmptyState(
      icon: Icons.note_outlined,
      message: 'No notes yet',
    )));
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.byIcon(Icons.note_outlined), findsOneWidget);
  });

  testWidgets('action button fires when provided', (t) async {
    var pressed = false;
    await t.pumpWidget(_host(AppEmptyState(
      icon: Icons.note_outlined,
      message: 'No notes yet',
      actionLabel: 'Add note',
      onAction: () => pressed = true,
    )));
    await t.tap(find.text('Add note'));
    expect(pressed, isTrue);
  });
}
