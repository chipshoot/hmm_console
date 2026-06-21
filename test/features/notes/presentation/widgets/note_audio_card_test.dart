import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_audio_card.dart';

void main() {
  testWidgets('renders name + a play button and a remove button', (t) async {
    var removed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteAudioCard(
          name: 'recording-1.m4a',
          resolvePath: () async => '/tmp/x.m4a',
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.text('recording-1.m4a'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });

  testWidgets('read-only hides the remove button', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteAudioCard(
            name: 'a.m4a', resolvePath: () async => '/tmp/x.m4a', readOnly: true),
      ),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
