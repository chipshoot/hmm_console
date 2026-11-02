import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/presentation/contact_note_display.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_results.dart';
import 'package:hmm_console/features/notes/query/saved_search.dart';
import 'package:hmm_console/features/notes/states/saved_searches_provider.dart';
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

const _counted = NoteCatalog(
  id: 9,
  name: 'Test.Counted',
  schema: '{}',
  formatType: 0,
  isDefault: false,
);

/// Counts title lookups, to tell whether an indexing is reused.
class _CountingEntry implements NoteDisplayEntry {
  int titles = 0;
  @override
  String title(HmmNote note, l) {
    titles++;
    return 'Counted ${note.id}';
  }

  @override
  NoteDisplay display(HmmNote note, l) => (title: title(note, l), preview: '');

  @override
  NoteTarget? target(HmmNote note) => null;
}

ProviderContainer _container(
  String text, {
  List<HmmNote>? notes,
  Map<int, NoteCatalog> catalogs = const <int, NoteCatalog>{},
  List<Override> overrides = const [],
  NoteQuery? query,
  List<SavedSearch> saved = const [],
}) {
  final data = NotesListData(
    all:
        notes ??
        [_n(1, 'Alpha', content: 'needs **zebra** stripes'), _n(2, 'Beta')],
    catalogsById: catalogs,
    query: query ?? NoteQuery(text: text),
  );
  final c = ProviderContainer(
    overrides: [
      notesListStateProvider.overrideWith(() => _FakeList(data)),
      pinyinTranscriberProvider.overrideWithValue(_Pinyin()),
      savedSearchesProvider.overrideWith(() => _FakeSaved(saved)),
      ...overrides,
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Waits until the warmer has indexed [count] notes.
Future<void> _warmed(ProviderContainer c, int count) async {
  final cache = c.read(noteTextIndexCacheProvider);
  for (var i = 0; i < 400 && cache.length < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(cache.length, count);
}

List<int> _ids(AsyncValue<dynamic> v) => [
  for (final g in v.requireValue.groups)
    for (final h in g.hits) h.note.id,
];

class _FakeSaved extends SavedSearchesNotifier {
  _FakeSaved(this.items);
  final List<SavedSearch> items;
  @override
  List<SavedSearch> build() => items;
}

void main() {
  test('a smart source lists the saved search\'s notes', () async {
    final c = _container(
      '',
      query: const NoteQuery(source: SmartSource(savedId: 's1')),
      saved: const [
        SavedSearch(
          id: 's1',
          name: 'S',
          order: 0,
          query: NoteQuery(text: 'alpha'),
        ),
      ],
    );
    await c.read(notesListStateProvider.future);
    c.listen(notesResultsProvider, (_, _) {});
    c.read(notesViewEnvProvider.notifier).set(_env);
    c.read(notesResultsProvider);
    await _warmed(c, 2);
    await Future<void>.delayed(Duration.zero);
    expect(_ids(c.read(notesResultsProvider)), [1]);
  });

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
    await _warmed(c, 2);
    await Future<void>.delayed(Duration.zero);
    expect(_ids(c.read(notesResultsProvider)), [1]);
  });

  test('keystrokes reuse the indexing built for the corpus', () async {
    final entry = _CountingEntry();
    final c = _container(
      '',
      notes: [
        for (var i = 1; i <= 3; i++)
          HmmNote(
            id: i,
            uuid: 'u$i',
            subject: 's$i',
            authorId: 1,
            catalogId: _counted.id,
            createDate: DateTime(2026, 1, i),
          ),
      ],
      catalogs: const {9: _counted},
      overrides: [
        noteDisplayRegistryProvider.overrideWithValue(
          NoteDisplayRegistry({_counted.name: entry}),
        ),
      ],
    );
    await c.read(notesListStateProvider.future);
    c.listen(notesResultsProvider, (_, _) {});
    c.read(notesViewEnvProvider.notifier).set(_env);
    c.read(notesResultsProvider);
    await _warmed(c, 3);
    final list = c.read(notesListStateProvider.notifier);
    list.setText('counted');
    c.read(notesResultsProvider);
    final afterFirst = entry.titles;
    list.setText('counted 2');
    expect(_ids(c.read(notesResultsProvider)), [2]);
    list.setText('counted');
    c.read(notesResultsProvider);
    expect(entry.titles, afterFirst);
  });

  test(
    'warming does not re-evaluate results while nothing is searched',
    () async {
      final c = _container(
        '',
        notes: [for (var i = 1; i <= 300; i++) _n(i, 'n$i', content: 'b $i')],
      );
      await c.read(notesListStateProvider.future);
      final seen = <AsyncValue<NoteResults>>[];
      c.listen(notesResultsProvider, (_, v) => seen.add(v));
      c.read(notesViewEnvProvider.notifier).set(_env);
      c.read(notesResultsProvider);
      final before = seen.length;
      await _warmed(c, 300);
      await Future<void>.delayed(Duration.zero);
      c.read(notesResultsProvider);
      expect(seen.length, before);
    },
  );

  test('a contact note is found by its title, never by its raw JSON', () async {
    const contacts = NoteCatalog(
      id: 2,
      name: ContactNoteDisplay.catalogName,
      schema: '{}',
      formatType: 0,
      isDefault: false,
    );
    const contact = Contact(
      id: 'c-1',
      contactType: ContactType.person,
      firstName: 'Wei',
      lastName: 'Zhang',
      notes: 'qqxyzzy secret token',
    );
    final note = HmmNote(
      id: 1,
      uuid: 'u1',
      subject: 'Contact:c-1',
      authorId: 1,
      catalogId: 2,
      createDate: DateTime(2026, 6, 1),
      content: jsonEncode({
        'note': {
          'content': {'Contact': ContactCodec.toMap(contact)},
        },
      }),
    );
    final c = _container(
      'qqxyzzy',
      notes: [note],
      catalogs: const {2: contacts},
    );
    await c.read(notesListStateProvider.future);
    c.listen(notesResultsProvider, (_, _) {});
    c.read(notesViewEnvProvider.notifier).set(_env);
    c.read(notesResultsProvider);
    await _warmed(c, 1);
    await Future<void>.delayed(Duration.zero);
    expect(_ids(c.read(notesResultsProvider)), isEmpty);
    final list = c.read(notesListStateProvider.notifier);
    list.setText('wei');
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
