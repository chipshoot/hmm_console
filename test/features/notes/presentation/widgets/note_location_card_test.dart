import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_location_card.dart';

void main() {
  testWidgets('shows label and a remove button when not read-only', (t) async {
    var removed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteLocationCard(
          location: const NoteLocation(
              latitude: 47.6, longitude: -122.3, label: 'Seattle, WA'),
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.text('Seattle, WA'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });

  testWidgets('falls back to coordinates and hides remove when read-only',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteLocationCard(
          location: const NoteLocation(latitude: 47.6, longitude: -122.3),
          readOnly: true,
        ),
      ),
    ));
    expect(find.textContaining('47.6'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
