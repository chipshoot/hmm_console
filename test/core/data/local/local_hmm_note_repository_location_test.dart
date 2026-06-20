import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';

void main() {
  late HmmDatabase db;
  late Author author;
  late int catalogId;
  late LocalHmmNoteRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'tester'),
        );
    author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    catalogId = await db.into(db.noteCatalogs).insert(
          NoteCatalogsCompanion.insert(name: 'C', schema: '{}'),
        );
    repo = LocalHmmNoteRepository(db, () async => author);
  });

  tearDown(() async => db.close());

  test('createNote with no location leaves all three null', () async {
    final n =
        await repo.createNote(HmmNoteCreate(subject: 's', catalogId: catalogId));
    expect(n.location, isNull);
    expect(n.latitude, isNull);
  });

  test('createNote writes the location trio', () async {
    final n = await repo.createNote(HmmNoteCreate(
      subject: 's',
      catalogId: catalogId,
      location:
          const NoteLocation(latitude: 47.6, longitude: -122.3, label: 'Seattle'),
    ));
    expect(n.latitude, 47.6);
    expect(n.longitude, -122.3);
    expect(n.locationLabel, 'Seattle');
  });

  test('updateNote with empty location clears the trio', () async {
    final created = await repo.createNote(HmmNoteCreate(
      subject: 's',
      catalogId: catalogId,
      location: const NoteLocation(latitude: 1, longitude: 2, label: 'X'),
    ));
    final updated = await repo.updateNote(
        created.id, const HmmNoteUpdate(location: NoteLocation.empty));
    expect(updated.location, isNull);
    expect(updated.latitude, isNull);
    expect(updated.locationLabel, isNull);
  });

  test('updateNote with null location leaves it untouched', () async {
    final created = await repo.createNote(HmmNoteCreate(
      subject: 's',
      catalogId: catalogId,
      location: const NoteLocation(latitude: 1, longitude: 2, label: 'X'),
    ));
    final updated =
        await repo.updateNote(created.id, const HmmNoteUpdate(subject: 's2'));
    expect(updated.latitude, 1);
    expect(updated.locationLabel, 'X');
  });
}
