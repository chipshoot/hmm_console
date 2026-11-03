// A note belongs to what it is attached to. A General note under a car is an
// automobile note — it filters under Automobile and NOT under General, the
// same way a note attached to a subsystem anchor already behaved. A record
// that already belongs to the domain it hangs under (a service record on a
// car) keeps filtering by its exact catalog, so picking one catalog in the
// filter sheet does not drag in its whole domain.

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_query_engine.dart';
import 'package:hmm_console/features/notes/query/note_text_index.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

const _general = 1;
const _autoInfo = 2;
const _serviceRecord = 3;

NoteCatalog _cat(int id, String name) => NoteCatalog(
  id: id,
  name: name,
  schema: '{}',
  formatType: 0,
  isDefault: false,
);

HmmNote _note(int id, {int? catalogId, int? parentNoteId, String? subject}) =>
    HmmNote(
      id: id,
      uuid: 'u$id',
      subject: subject ?? 'note $id',
      authorId: 1,
      catalogId: catalogId,
      parentNoteId: parentNoteId,
      createDate: DateTime(2026, 1, id),
    );

/// The car (id 100), the notes hanging off it, and some controls.
NotesListData _data({NoteQuery query = const NoteQuery.initial()}) {
  final all = [
    _note(100, catalogId: _autoInfo, subject: '2019 Honda Civic'),
    _note(1, catalogId: _general, parentNoteId: 100, subject: 'Winter tyres'),
    _note(2, catalogId: _general, subject: 'Buy milk'),
    _note(3, catalogId: _serviceRecord, parentNoteId: 100),
    _note(4, catalogId: _general, parentNoteId: 2),
    _note(5, catalogId: _general, parentNoteId: 999), // dangling parent
    _note(6, catalogId: _general, parentNoteId: 900), // anchor parent
  ];
  return NotesListData(
    all: all,
    catalogsById: {
      _general: _cat(_general, 'General'),
      _autoInfo: _cat(_autoInfo, 'Hmm.AutomobileMan.AutomobileInfo'),
      _serviceRecord: _cat(_serviceRecord, 'Hmm.AutomobileMan.ServiceRecord'),
    },
    query: query,
    catalogDomainById: const {
      _general: 'General',
      _autoInfo: 'AutomobileMan',
      _serviceRecord: 'AutomobileMan',
    },
    anchorDomainById: const {900: 'AutomobileMan'},
    targetsById: const {
      100: (domain: 'AutomobileMan', subject: '2019 Honda Civic'),
      2: (domain: 'General', subject: 'Buy milk'),
    },
  );
}

Set<int> ids(NotesListData d) {
  final engine = InMemoryNoteQueryEngine(
    cache: NoteTextIndexCache(),
    keyOf: (n) =>
        (noteId: n.id, version: '', locale: '', parentTitle: '', tags: ''),
    titleOf: (n) => n.subject,
    pinyin: _NoPinyin(),
  );
  final r = engine.evaluate(
    d.query,
    d,
    now: DateTime(2026, 6, 1),
    firstDayOfWeek: 1,
  );
  return {
    for (final g in r.groups)
      for (final h in g.hits) h.note.id,
  };
}

class _NoPinyin implements PinyinTranscriber {
  @override
  List<String> given(String text) => [text];
  @override
  List<String> family(String text) => [text];
}

NotesListData _filtered(NoteSource source) =>
    _data(query: NoteQuery(source: source));

void main() {
  group('effectiveDomain', () {
    final d = _data();
    HmmNote byId(int id) => d.all.firstWhere((n) => n.id == id);

    test('a General note under a car is an automobile note', () {
      expect(d.effectiveDomain(byId(1)), 'AutomobileMan');
      expect(d.contextSubjectOf(byId(1)), '2019 Honda Civic');
    });

    test('an unattached General note stays General', () {
      expect(d.effectiveDomain(byId(2)), 'General');
      expect(d.contextSubjectOf(byId(2)), isNull);
    });

    test('a note under an anchor takes its domain, with no subject', () {
      expect(d.effectiveDomain(byId(6)), 'AutomobileMan');
      expect(d.contextSubjectOf(byId(6)), isNull);
    });

    test('a dangling parent falls back to the catalog domain', () {
      expect(d.effectiveDomain(byId(5)), 'General');
    });

    test('a note under a General note stays General', () {
      expect(d.effectiveDomain(byId(4)), 'General');
    });
  });

  group('the Automobile domain filter', () {
    // The drawer selects every catalog in the domain.
    final automobile = _filtered(const DomainSource(key: 'AutomobileMan'));

    test('shows the car, its service record, its note, the anchor note', () {
      expect(ids(automobile), {100, 3, 1, 6});
    });

    test('leaves unattached General notes out', () {
      expect(ids(automobile), isNot(contains(2)));
    });
  });

  group('the General domain filter', () {
    final general = _filtered(const DomainSource(key: 'General'));

    test('a note attached to a car has moved out of General', () {
      expect(ids(general), isNot(contains(1)));
    });

    test('unattached and General-parented notes stay', () {
      expect(ids(general), containsAll(<int>{2, 4, 5}));
    });
  });

  test('picking one catalog does not drag in the whole domain', () {
    // Only "Service record" selected: the car itself must not appear.
    final only = _filtered(
      const DomainSource(key: 'AutomobileMan', catalogId: _serviceRecord),
    );
    expect(ids(only), contains(3));
    expect(ids(only), isNot(contains(100)));
  });

  test('search matches the parent subject as well as the subject', () {
    expect(ids(_data(query: const NoteQuery(text: 'honda'))), contains(1));
    expect(ids(_data(query: const NoteQuery(text: 'tyres'))), contains(1));
    expect(
      ids(_data(query: const NoteQuery(text: 'honda'))),
      isNot(contains(2)),
    );
  });

  group('counts agree with what the filter shows', () {
    // Only car notes: the car itself plus two General notes attached to it —
    // no unattached General note anywhere. Built with the same _cat/_note
    // helpers as _data(), just without the extra General fixtures.
    NotesListData onlyCarNotes() {
      final all = [
        _note(100, catalogId: _autoInfo, subject: '2019 Honda Civic'),
        _note(
          1,
          catalogId: _general,
          parentNoteId: 100,
          subject: 'Winter tyres',
        ),
        _note(2, catalogId: _general, parentNoteId: 100, subject: 'Oil change'),
      ];
      return NotesListData(
        all: all,
        catalogsById: {
          _general: _cat(_general, 'General'),
          _autoInfo: _cat(_autoInfo, 'Hmm.AutomobileMan.AutomobileInfo'),
        },
        catalogDomainById: const {
          _general: 'General',
          _autoInfo: 'AutomobileMan',
        },
        targetsById: const {
          100: (domain: 'AutomobileMan', subject: '2019 Honda Civic'),
        },
      );
    }

    test('the General group has no notes to show', () {
      final d = onlyCarNotes();
      expect(d.countsByDomain['General'] ?? 0, 0);
    });

    test('the Automobile group count matches what selecting it shows', () {
      final d = onlyCarNotes();
      final autoSelected = d.copyWith(
        query: NoteQuery(source: const DomainSource(key: 'AutomobileMan')),
      );
      expect(d.countsByDomain['AutomobileMan'], ids(autoSelected).length);
      expect(ids(autoSelected).length, 3); // car + both attached notes
    });
  });
}
