import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

class _FakeMutate implements MutateNote {
  int? createdParent;
  bool createCalled = false;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<HmmNote> createGeneral(
      {required String subject,
      String? markdownBody,
      int? parentNoteId,
      DateTime? noteDate,
      NoteLocation? location}) async {
    createCalled = true;
    createdParent = parentNoteId;
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1), parentNoteId: parentNoteId);
  }
}

void main() {
  testWidgets('preset parent is used on create', (tester) async {
    final fake = _FakeMutate();
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => const Scaffold(body: Text('Home')),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (ctx, state) =>
                  const NoteEditorScreen(presetParentId: 7),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mutateNoteProvider.overrideWithValue(fake),
        subsystemAnchorsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [AppColors.light]),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Hi');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(fake.createCalled, isTrue);
    expect(fake.createdParent, 7);
  });
}
