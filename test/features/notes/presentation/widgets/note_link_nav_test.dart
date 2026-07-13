import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_markdown_body.dart';

/// Fake repository that only implements [getNoteByUuid]; every other member
/// falls through to [noSuchMethod] so this test doesn't need to stub the
/// whole [IHmmNoteRepository] surface.
class _FakeRepo implements IHmmNoteRepository {
  _FakeRepo(this._result);

  final HmmNote? _result;

  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => _result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repository whose [getNoteByUuid] throws — e.g. no signed-in author.
class _ThrowingRepo implements IHmmNoteRepository {
  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async =>
      throw StateError('no author');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HmmNote _note({required int id, required String uuid}) => HmmNote(
      id: id,
      uuid: uuid,
      subject: 'Linked note',
      authorId: 1,
      createDate: DateTime(2026, 1, 1),
    );

GoRouter _router() => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: MarkdownView('[go](hmm-note://u1)'),
          ),
        ),
        GoRoute(
          path: '/notes/:id',
          builder: (context, state) => Scaffold(
            body: Text('note-detail-${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, IHmmNoteRepository repo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      hmmNoteRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: _router()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a resolvable note link navigates to /notes/<id>',
      (tester) async {
    await _pump(tester, _FakeRepo(_note(id: 7, uuid: 'u1')));

    final body =
        tester.widget<NoteMarkdownBody>(find.byType(NoteMarkdownBody));
    body.onNoteLinkTap!('u1');
    await tester.pumpAndSettle();

    expect(find.text('note-detail-7'), findsOneWidget);
    expect(find.byType(MarkdownView), findsNothing);
  });

  testWidgets(
      'tapping an unresolvable note link shows an unavailable SnackBar',
      (tester) async {
    await _pump(tester, _FakeRepo(null));

    final body =
        tester.widget<NoteMarkdownBody>(find.byType(NoteMarkdownBody));
    body.onNoteLinkTap!('u1');
    await tester.pumpAndSettle();

    expect(find.text('Linked note unavailable'), findsOneWidget);
    // No navigation happened — still on the home route.
    expect(find.byType(MarkdownView), findsOneWidget);
  });

  testWidgets('a throwing resolver shows the unavailable SnackBar (no crash)',
      (tester) async {
    await _pump(tester, _ThrowingRepo());

    final body =
        tester.widget<NoteMarkdownBody>(find.byType(NoteMarkdownBody));
    body.onNoteLinkTap!('u1');
    await tester.pumpAndSettle();

    expect(find.text('Linked note unavailable'), findsOneWidget);
    expect(find.byType(MarkdownView), findsOneWidget);
  });
}
