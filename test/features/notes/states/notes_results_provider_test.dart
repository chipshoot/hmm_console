import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/contacts/presentation/contact_note_display.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/rendering/note_display.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/features/notes/states/notes_results_provider.dart';

class _Pinyin implements PinyinTranscriber {
  @override
  List<String> given(String text) => [text];
  @override
  List<String> family(String text) => [text];
}

class _FakeList extends NotesListState {
  _FakeList(this.data);
  final NotesListData data;
  @override
  Future<NotesListData> build() async => data;
}

HmmNote _n(int id, String subject, {String? content}) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
  authorId: 1,
  createDate: DateTime(2026, 1, id),
  content: content,
);

const _env = (locale: Locale('en'), firstDayOfWeek: 1);

ProviderContainer _container(String text) {
  final data = NotesListData(
    all: [
      _n(1, 'Alpha', content: 'needs **zebra** stripes'),
      _n(2, 'Beta'),
    ],
    catalogsById: const <int, NoteCatalog>{},
    query: NoteQuery(text: text),
  );
  final c = ProviderContainer(
    overrides: [
      notesListStateProvider.overrideWith(() => _FakeList(data)),
      pinyinTranscriberProvider.overrideWithValue(_Pinyin()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

List<int> _ids(AsyncValue<dynamic> v) => [
  for (final g in v.requireValue.groups)
    for (final h in g.hits) h.note.id,
];

void main() {
  test('results wait for the view env', () async {
    final c = _container('');
    await c.read(notesListStateProvider.future);
    expect(c.read(notesResultsProvider), isA<AsyncLoading>());
  });

  test('results update once the warmer makes body text searchable', () async {
    final c = _container('zebra');
    await c.read(notesListStateProvider.future);
    c.listen(notesResultsProvider, (_, _) {});
    c.read(notesViewEnvProvider.notifier).set(_env);
    expect(_ids(c.read(notesResultsProvider)), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(_ids(c.read(notesResultsProvider)), [1]);
  });

  test('setting an equal env is a no-op', () {
    final c = _container('');
    final n = c.read(notesViewEnvProvider.notifier)..set(_env);
    final before = c.read(notesViewEnvProvider);
    n.set(_env);
    expect(identical(c.read(notesViewEnvProvider), before), isTrue);
  });

  test('registry reports which catalogs have an entry', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final r = c.read(noteDisplayRegistryProvider);
    expect(r.hasEntry(null), isFalse);
    expect(r.hasEntry('Nope'), isFalse);
    expect(r.hasEntry(ContactNoteDisplay.catalogName), isTrue);
  });
}
