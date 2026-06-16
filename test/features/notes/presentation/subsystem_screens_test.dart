import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/subsystem_notes_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/subsystems_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';

void main() {
  testWidgets('SubsystemsScreen lists anchors', (tester) async {
    final anchor = HmmNote(
      id: 5,
      uuid: 'hmm-subsystem-automobile',
      subject: 'Automobile',
      authorId: 1,
      catalogId: 9,
      createDate: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsystemAnchorsProvider.overrideWith((ref) async => [anchor]),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: const SubsystemsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Automobile'), findsOneWidget);
  });

  testWidgets('SubsystemNotesScreen hosts the anchor notes section', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachedNotesProvider(5).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: const SubsystemNotesScreen(anchorId: 5, anchorName: 'Automobile'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AttachedNotesSection), findsOneWidget);
    expect(find.text('Automobile notes'), findsWidgets);
  });
}
