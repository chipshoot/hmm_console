import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_media_card_list.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC');

class _FakeSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(bytes: _png, originalName: 'a.jpg');
}

class _FakeMutate implements MutateNote {
  int attachCalls = 0;
  @override
  Future<HmmNote> createGeneral(
      {required String subject, String? markdownBody, int? parentNoteId}) async {
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1));
  }

  @override
  Future<HmmNote?> attachImageBytes(int noteId, PickedImageBytes pick) async {
    attachCalls++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('add photo shows a pending card before save; save attaches it',
      (tester) async {
    final fake = _FakeMutate();
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
        mutateNoteProvider.overrideWithValue(fake),
        imageByteSourceProvider.overrideWithValue(_FakeSource()),
        subsystemAnchorsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [AppColors.light]),
      ),
    ));
    await tester.pumpAndSettle();

    // Add a photo (gallery) — no subject yet.
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(NoteMediaCard), findsOneWidget); // pending card shown

    // Enter subject and save → the pending pick is attached.
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Hello');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(fake.attachCalls, 1);
  });
}
