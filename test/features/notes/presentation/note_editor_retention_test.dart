import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

const _inline = VaultRef(
    path: 'attachments/note-1/a.jpg', contentType: 'image/jpeg', byteSize: 3);

HmmNote _noteWithInlineImage() => HmmNote(
      id: 1, uuid: 'u', subject: 'Has image', authorId: 1,
      catalogId: 1,
      content:
          'before\n\n![a](hmm-attachment://attachments/note-1/a.jpg)\n\nafter',
      attachments: NoteAttachments(images: const [_inline]),
      createDate: DateTime(2026, 1, 1),
    );

class _FakeRepo implements IHmmNoteRepository {
  @override
  Future<HmmNote?> getNoteById(int id) async => _noteWithInlineImage();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeMutate implements MutateNote {
  NoteAttachments? lastAttachments;
  int setAttachmentsCalls = 0;

  @override
  Future<HmmNote> updateGeneral(int id,
          {String? subject,
          String? markdownBody,
          DateTime? noteDate,
          NoteLocation? location}) async =>
      _noteWithInlineImage();

  @override
  Future<HmmNote?> setAttachments(int noteId, NoteAttachments atts) async {
    setAttachmentsCalls++;
    lastAttachments = atts;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

GoRouter _router() => GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
                path: 'editor',
                builder: (c, s) => const NoteEditorScreen(noteId: 1)),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, _FakeMutate mutate) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mutateNoteProvider.overrideWithValue(mutate),
      hmmNoteRepositoryProvider.overrideWith((ref) => _FakeRepo()),
      subsystemAnchorsProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp.router(
      routerConfig: _router(),
      theme: ThemeData(extensions: const [AppColors.light]),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _removeInlineLineAndSave(WidgetTester tester) async {
  // Replace the body with one that no longer references the inline image.
  final body = find.widgetWithText(TextField, 'Start writing…');
  await tester.enterText(body, 'before\n\nafter');
  await tester.pump();
  await tester.tap(find.text('Save'));
  // Use pump (not pumpAndSettle): _save stays suspended awaiting the confirm
  // dialog while the busy spinner animates, so pumpAndSettle would time out.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('removing an inline image prompts before dropping it; Keep retains',
      (tester) async {
    final mutate = _FakeMutate();
    await _pump(tester, mutate);
    await _removeInlineLineAndSave(tester);

    // Confirmation appears.
    expect(find.text('Remove stored images?'), findsOneWidget);
    await tester.tap(find.text('Keep attached'));
    await tester.pumpAndSettle();

    // The ref is retained.
    expect(mutate.setAttachmentsCalls, 1);
    expect(mutate.lastAttachments!.images.whereType<VaultRef>().map((r) => r.path),
        contains('attachments/note-1/a.jpg'));
  });

  testWidgets('removing an inline image; Delete drops the stored ref',
      (tester) async {
    final mutate = _FakeMutate();
    await _pump(tester, mutate);
    await _removeInlineLineAndSave(tester);

    expect(find.text('Remove stored images?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(mutate.setAttachmentsCalls, 1);
    expect(mutate.lastAttachments!.images, isEmpty);
  });
}
