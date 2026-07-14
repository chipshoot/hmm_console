import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _FakeSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async => null;
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
  Future<HmmNote> updateGeneral(int id,
      {String? subject,
      String? markdownBody,
      DateTime? noteDate,
      NoteLocation? location}) async {
    return HmmNote(
        id: 1, uuid: 'u', subject: 's', authorId: 1,
        createDate: DateTime(2026, 1, 1));
  }

  @override
  Future<VaultRef> persistInlineImage(
          int noteId, PickedImageBytes pick) async =>
      const VaultRef(
          path: 'attachments/note-1/a.jpg',
          contentType: 'image/jpeg',
          byteSize: 3);

  @override
  Future<HmmNote?> setAttachments(int noteId, NoteAttachments atts) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 9, uuid: 'u9', subject: 'Target', authorId: 1,
              createDate: DateTime(2026, 1, 1)),
        ],
        catalogsById: const {},
      );
}

GoRouter _router() => GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
                path: 'editor', builder: (c, s) => const NoteEditorScreen()),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, MutateNote mutate) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mutateNoteProvider.overrideWithValue(mutate),
      imageByteSourceProvider.overrideWithValue(_FakeSource()),
      subsystemAnchorsProvider.overrideWith((ref) async => const []),
      notesListStateProvider.overrideWith(_StubListState.new),
    ],
    child: MaterialApp.router(
      routerConfig: _router(),
      theme: ThemeData(extensions: const [AppColors.light]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'link-to-note toolbar action picks a note and inserts a note link',
      (tester) async {
    await _pump(tester, _FakeMutate());

    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();

    expect(find.text('Target'), findsOneWidget);
    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();

    final body = find.widgetWithText(TextField, 'Start writing…');
    final bodyText = tester.widget<TextField>(body).controller!.text;
    expect(bodyText, contains('[Target](hmm-note://u9)'));
  });
}
