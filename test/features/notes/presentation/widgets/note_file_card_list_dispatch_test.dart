import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_audio_card.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_file_card.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_file_card_list.dart';

const _pdf = VaultRef(
    path: 'attachments/n/r.pdf', contentType: 'application/pdf', byteSize: 3);
const _audio = VaultRef(
    path: 'attachments/n/rec.m4a', contentType: 'audio/mp4', byteSize: 9);

void main() {
  testWidgets('audio ref → NoteAudioCard, pdf ref → NoteFileCard', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: NoteFileCardList(saved: const [_pdf, _audio], readOnly: true),
        ),
      ),
    ));
    expect(find.byType(NoteFileCard), findsOneWidget);
    expect(find.byType(NoteAudioCard), findsOneWidget);
  });
}
