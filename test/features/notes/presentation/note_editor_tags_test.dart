import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_tag_field.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

HmmNote _note(int id, {int? parent}) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: 'My note',
  authorId: 1,
  createDate: DateTime(2026, 1, 1),
  content: 'body',
  parentNoteId: parent,
);

class _FakeNotes implements IHmmNoteRepository {
  @override
  Future<HmmNote?> getNoteById(int id) async => _note(id);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTags implements ITagRepository {
  _FakeTags({this.byNote = const {}});
  final Map<int, List<NoteTagLabel>> byNote;
  final ensured = <String>[];
  int _next = 100;

  @override
  Stream<Map<int, List<NoteTagLabel>>> watchNoteTags() => Stream.value(byNote);
  @override
  Stream<Map<int, String>> watchLiveTagNames() => Stream.value(const {});
  @override
  Future<Tag> ensureTag(String name) async {
    ensured.add(name);
    return Tag(
      id: _next++,
      name: name,
      isActivated: true,
      lastModified: DateTime(2026),
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeMutate implements MutateNote {
  final setTagsCalls = <String>[];
  @override
  Future<HmmNote> createGeneral({
    required String subject,
    String? markdownBody,
    int? parentNoteId,
    DateTime? noteDate,
    NoteLocation? location,
  }) async => _note(7);
  @override
  Future<HmmNote> updateGeneral(
    int id, {
    String? subject,
    String? markdownBody,
    DateTime? noteDate,
    NoteLocation? location,
  }) async => _note(id);
  @override
  Future<void> setTags(int noteId, Set<int> tagIds) async =>
      setTagsCalls.add('$noteId:${(tagIds.toList()..sort()).join(',')}');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeList extends NotesListState {
  _FakeList(this.data);
  final NotesListData data;
  @override
  Future<NotesListData> build() async => data;
}

void main() {
  late _FakeTags tags;
  late _FakeMutate mutate;

  Future<ProviderContainer> open(
    WidgetTester t, {
    int? noteId,
    int? presetParentId,
    NotesListData? list,
  }) async {
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (_, _) => NoteEditorScreen(
                noteId: noteId,
                presetParentId: presetParentId,
              ),
            ),
          ],
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        hmmNoteRepositoryProvider.overrideWithValue(_FakeNotes()),
        tagRepositoryProvider.overrideWithValue(tags),
        mutateNoteProvider.overrideWithValue(mutate),
        if (list != null)
          notesListStateProvider.overrideWith(() => _FakeList(list)),
      ],
    );
    addTearDown(container.dispose);
    if (list != null) await container.read(notesListStateProvider.future);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColors.light]),
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
    return container;
  }

  NoteTagField field(WidgetTester t) =>
      t.widget<NoteTagField>(find.byType(NoteTagField));

  Future<void> addTag(WidgetTester t, String name) async {
    await t.enterText(
      find.descendant(
        of: find.byType(NoteTagField),
        matching: find.byType(TextField),
      ),
      name,
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
  }

  setUp(() {
    tags = _FakeTags();
    mutate = _FakeMutate();
  });

  testWidgets(
    'saving a new note with two tags creates them and sets membership',
    (t) async {
      await open(t);
      await t.enterText(find.byType(TextField).first, 'Title');
      await addTag(t, 'one');
      await addTag(t, 'two');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(tags.ensured, ['one', 'two']);
      expect(mutate.setTagsCalls, ['7:100,101']);
    },
  );

  testWidgets('editing an existing note shows its tags and saves changes', (
    t,
  ) async {
    tags = _FakeTags(
      byNote: {
        3: [(id: 1, name: 'keep'), (id: 2, name: 'drop')],
      },
    );
    await open(t, noteId: 3);
    expect(field(t).names, ['keep', 'drop']);
    await t.tap(find.byTooltip('Remove tag drop'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(tags.ensured, ['keep']);
    expect(mutate.setTagsCalls, ['3:100']);
  });

  testWidgets('unchanged tags do not call setTags', (t) async {
    tags = _FakeTags(
      byNote: {
        3: [(id: 1, name: 'keep')],
      },
    );
    await open(t, noteId: 3);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(mutate.setTagsCalls, isEmpty);
  });

  NotesListData listFor(NoteSource source, {Map<int, String>? names}) =>
      NotesListData(
        all: const [],
        catalogsById: const {},
        query: NoteQuery.initial().copyWith(source: source),
        liveTagNames: names,
      );

  testWidgets('new note opened while TagSource(t) is current starts with t', (
    t,
  ) async {
    await open(
      t,
      list: listFor(const TagSource(tagId: 5), names: {5: 'Groceries'}),
    );
    expect(field(t).names, ['Groceries']);
  });

  testWidgets('new note with a parent preset does not prefill', (t) async {
    await open(
      t,
      presetParentId: 9,
      list: listFor(const TagSource(tagId: 5), names: {5: 'Groceries'}),
    );
    expect(field(t).names, isEmpty);
  });

  testWidgets('no prefill when liveTagNames is not loaded', (t) async {
    await open(t, list: listFor(const TagSource(tagId: 5)));
    expect(field(t).names, isEmpty);
  });
}
