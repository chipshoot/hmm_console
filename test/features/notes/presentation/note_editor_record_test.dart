import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/recorder/audio_recorder.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_audio_card.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

class _FakeRecorder implements AudioRecorderService {
  bool started = false;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start() async => started = true;
  @override
  Future<AudioRecording?> stop() async =>
      AudioRecording(bytes: Uint8List.fromList([1, 2, 3]), fileName: 'rec.m4a');
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

class _FakeMutate implements MutateNote {
  @override
  Future<HmmNote> createGeneral(
      {required String subject,
      String? markdownBody,
      int? parentNoteId,
      DateTime? noteDate,
      NoteLocation? location}) async {
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('recording via the mic button shows a pending audio card',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(path: 'editor', builder: (c, s) => const NoteEditorScreen()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mutateNoteProvider.overrideWithValue(_FakeMutate()),
        audioRecorderProvider.overrideWithValue(_FakeRecorder()),
        subsystemAnchorsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [AppColors.light]),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteAudioCard), findsOneWidget);
  });
}
