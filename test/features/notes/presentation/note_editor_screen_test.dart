import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

class _FakeMutate implements MutateNote {
  String? createdSubject;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<HmmNote> createGeneral({required String subject, String? markdownBody, int? parentNoteId, DateTime? noteDate}) async {
    createdSubject = subject;
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1), content: markdownBody);
  }
}

void main() {
  testWidgets('Save with empty subject shows validation error', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NoteEditorScreen(),
      ),
    ));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Subject is required'), findsOneWidget);
  });

  testWidgets('Save with a subject calls createGeneral', (tester) async {
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
              builder: (ctx, state) => const NoteEditorScreen(),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [mutateNoteProvider.overrideWithValue(fake)],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [AppColors.light]),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Hello');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(fake.createdSubject, 'Hello');
  });
}
