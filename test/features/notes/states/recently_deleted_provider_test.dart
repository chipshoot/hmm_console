import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_contact_repository.dart'
    show contactCatalogName;
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/recently_deleted_provider.dart';

class _Notes implements IHmmNoteRepository {
  _Notes(this.notes);
  final List<HmmNote> notes;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Stream<List<HmmNote>> watchDeletedNotes() => Stream.value(notes);
}

class _StreamNotes implements IHmmNoteRepository {
  _StreamNotes(this.s);
  final Stream<List<HmmNote>> s;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Stream<List<HmmNote>> watchDeletedNotes() => s;
}

class _Catalogs implements INoteCatalogRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Stream<List<NoteCatalog>> watchCatalogs() => Stream.value(const [
    NoteCatalog(
      id: 10,
      name: kGeneralCatalogName,
      schema: '{}',
      formatType: 0,
      isDefault: false,
    ),
    NoteCatalog(
      id: 11,
      name: contactCatalogName,
      schema: '{}',
      formatType: 0,
      isDefault: false,
    ),
  ]);
}

final _now = DateTime.utc(2026, 11, 3, 12);

HmmNote _note(int id, int catalog, Duration ago) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: 'N$id',
  authorId: 1,
  catalogId: catalog,
  createDate: DateTime.utc(2026),
  deletedAt: _now.subtract(ago),
);

ProviderContainer _container(List<HmmNote> notes) {
  final c = ProviderContainer(
    overrides: [
      hmmNoteRepositoryProvider.overrideWithValue(_Notes(notes)),
      noteCatalogRepositoryProvider.overrideWithValue(_Catalogs()),
      recentlyDeletedNowProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<List<DeletedNoteItem>> _items(ProviderContainer c) {
  c.listen(recentlyDeletedProvider, (_, _) {});
  return c.read(recentlyDeletedProvider.future);
}

Future<Set<int>> _ids(ProviderContainer c) {
  c.listen(deletedNoteIdsProvider, (_, _) {});
  return c.read(deletedNoteIdsProvider.future);
}

void main() {
  group('daysLeftFor', () {
    test('just deleted has 30 days', () {
      expect(daysLeftFor(_now, _now), 30);
    });
    test('29 days 23 hours ago has 1 day', () {
      expect(
        daysLeftFor(_now.subtract(const Duration(days: 29, hours: 23)), _now),
        1,
      );
    });
    test('one day ago has 29 days', () {
      expect(daysLeftFor(_now.subtract(const Duration(days: 1)), _now), 29);
    });
  });

  group('recentlyDeletedProvider', () {
    test('hides a note deleted 30 days and an hour ago', () async {
      final c = _container([
        _note(1, 10, const Duration(days: 30, hours: 1)),
        _note(2, 10, const Duration(days: 2)),
      ]);
      final items = await _items(c);
      expect(items.map((i) => i.note.id), [2]);
      expect(items.single.daysLeft, 28);
    });

    test('hides entity notes (G11) but lists General notes', () async {
      final c = _container([
        _note(1, 11, const Duration(days: 1)),
        _note(2, 10, const Duration(days: 1)),
      ]);
      final items = await _items(c);
      expect(items.map((i) => i.note.id), [2]);
    });

    test('lists newest deletion first', () async {
      final c = _container([
        _note(1, 10, const Duration(days: 5)),
        _note(2, 10, const Duration(days: 1)),
        _note(3, 10, const Duration(days: 3)),
      ]);
      final items = await _items(c);
      expect(items.map((i) => i.note.id), [2, 3, 1]);
    });
  });

  test(
    'the clock is read per emission, so a note that ages out drops',
    () async {
      var now = _now;
      final ctrl = StreamController<List<HmmNote>>();
      final c = ProviderContainer(
        overrides: [
          hmmNoteRepositoryProvider.overrideWithValue(
            _StreamNotes(ctrl.stream),
          ),
          noteCatalogRepositoryProvider.overrideWithValue(_Catalogs()),
          recentlyDeletedNowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(ctrl.close);
      final seen = <int>[];
      c.listen(recentlyDeletedProvider, (_, n) {
        if (n.hasValue) seen.add(n.value!.length);
      });
      final notes = [_note(1, 10, const Duration(days: 29))];
      await Future<void>.delayed(Duration.zero);
      ctrl.add(notes);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      now = _now.add(const Duration(days: 2));
      ctrl.add(notes);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(seen, [1, 0]);
    },
  );

  test('deletedNoteIdsProvider holds every deleted id, any catalog', () async {
    final c = _container([
      _note(1, 11, const Duration(days: 40)),
      _note(2, 10, const Duration(days: 1)),
    ]);
    expect(await _ids(c), {1, 2});
  });
}
