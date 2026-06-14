import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/vehicle_notes_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';

void main() {
  testWidgets('vehicle notes screen hosts AttachedNotesSection for the car',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(42).overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: VehicleNotesScreen(automobileId: 42)),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AttachedNotesSection), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
  });
}
