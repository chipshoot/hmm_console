import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';

void main() {
  late HmmDatabase db;
  late LocalTagRepository tags;
  late int authorId;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    tags = LocalTagRepository(db);
    authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'me'));
  });
  tearDown(() => db.close());

  final past = DateTime.utc(2026, 1, 1);

  Future<int> note({DateTime? deletedAt}) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          subject: 'n',
          authorId: authorId,
          lastModifiedDate: Value(past),
          deletedAt: Value(deletedAt),
        ),
      );

  Future<Note> noteRow(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

  Future<int> tag(String name) => db
      .into(db.tags)
      .insert(TagsCompanion.insert(name: name, lastModified: Value(past)));

  Future<void> ref(int noteId, int tagId) => db
      .into(db.noteTagRefs)
      .insert(NoteTagRefsCompanion.insert(noteId: noteId, tagId: tagId));

  Future<Set<int>> tagIdsOf(int noteId) async => (await (db.select(
    db.noteTagRefs,
  )..where((r) => r.noteId.equals(noteId))).get()).map((r) => r.tagId).toSet();

  Future<List<Tag>> allTags() => db.select(db.tags).get();

  test('normalizeTagName trims, collapses and bounds', () {
    expect(normalizeTagName('  Work  trip '), 'Work trip');
    expect(normalizeTagName('   '), isNull);
    expect(normalizeTagName('a' * 51), isNull);
    expect(normalizeTagName('a' * 50), 'a' * 50);
  });

  test('ensureTag returns the live tag case-insensitively', () async {
    final work = await tags.ensureTag('Work');
    final again = await tags.ensureTag(' work ');
    expect(again.id, work.id);
    expect(await allTags(), hasLength(1));
  });

  test('ensureTag revives a tombstoned name', () async {
    final work = await tags.ensureTag('Work');
    await tags.deleteTag(work.id);
    final dead = (await allTags()).single;
    expect(dead.deletedAt, isNotNull);

    final revived = await tags.ensureTag('work');
    expect(revived.id, work.id);
    expect(revived.deletedAt, isNull);
    expect(revived.isActivated, isTrue);
    expect(revived.lastModified.isAfter(dead.lastModified), isTrue);
    expect(await allTags(), hasLength(1));
  });

  test('ensureTag rejects empty and overlong names', () async {
    expect(() => tags.ensureTag('   '), throwsArgumentError);
    expect(() => tags.ensureTag('a' * 51), throwsArgumentError);
  });

  test('setNoteTags set-replaces and bumps the note', () async {
    final n = await note();
    final a = await tag('A');
    final b = await tag('B');
    final c = await tag('C');
    await ref(n, a);
    await ref(n, b);
    final before = await noteRow(n);

    await tags.setNoteTags(n, {b, c});

    expect((await tags.getTagsForNote(n)).map((t) => t.id).toSet(), {b, c});
    final after = await noteRow(n);
    expect(after.lastModifiedDate!.isAfter(before.lastModifiedDate!), isTrue);
    expect(after.version, isNotNull);
    expect(after.version, isNot(equals(before.version)));
  });

  test('setNoteTags with an unchanged set does not bump', () async {
    final n = await note();
    final a = await tag('A');
    await ref(n, a);
    final before = await noteRow(n);

    await tags.setNoteTags(n, {a});

    final after = await noteRow(n);
    expect(after.lastModifiedDate, before.lastModifiedDate);
    expect(after.version, before.version);
  });

  test('setNoteTags stamps strictly later within the same second', () async {
    final n = await note();
    final a = await tag('A');
    final b = await tag('B');

    await tags.setNoteTags(n, {a});
    final first = (await noteRow(n)).lastModifiedDate!;
    await tags.setNoteTags(n, {b});
    final second = (await noteRow(n)).lastModifiedDate!;

    expect(second.isAfter(first), isTrue);
  });

  test('setNoteTags fires onLocalWrite once per change', () async {
    var writes = 0;
    final counted = LocalTagRepository(db, onLocalWrite: () => writes++);
    final n = await note();
    final a = await tag('A');

    await counted.setNoteTags(n, {a});
    expect(writes, 1);
    await counted.setNoteTags(n, {a});
    expect(writes, 1);
  });

  test(
    'renameTag keeps the id, renames, tombstones the old name, bumps carriers',
    () async {
      final work = await tag('Work');
      final n1 = await note();
      final n2 = await note();
      await ref(n1, work);
      await ref(n2, work);

      await tags.renameTag(work, 'Trip');

      final rows = await allTags();
      final renamed = rows.singleWhere((t) => t.id == work);
      expect(renamed.name, 'Trip');
      expect(renamed.deletedAt, isNull);
      final tomb = rows.singleWhere((t) => t.name == 'Work');
      expect(tomb.deletedAt, isNotNull);
      expect(tomb.id, isNot(work));
      for (final n in [n1, n2]) {
        expect((await noteRow(n)).lastModifiedDate!.isAfter(past), isTrue);
        expect(await tagIdsOf(n), {work});
      }
    },
  );

  test('renameTag case-only renames in place without a tombstone', () async {
    final work = await tag('work');
    await tags.renameTag(work, 'Work');
    final rows = await allTags();
    expect(rows, hasLength(1));
    expect(rows.single.id, work);
    expect(rows.single.name, 'Work');
    expect(rows.single.deletedAt, isNull);
    expect(rows.single.lastModified.isAfter(past), isTrue);
  });

  test('renameTag onto a live name throws TagNameTaken(existingId)', () async {
    final work = await tag('Work');
    final trip = await tag('Trip');
    await expectLater(
      tags.renameTag(work, ' trip '),
      throwsA(isA<TagNameTaken>().having((e) => e.existingId, 'id', trip)),
    );
    expect((await tags.getTagById(work))!.name, 'Work');
  });

  test('renameTag onto a dead name reuses that name', () async {
    final trip = await tags.ensureTag('Trip');
    await tags.deleteTag(trip.id);
    final work = await tag('Work');

    await tags.renameTag(work, 'trip');

    final rows = await allTags();
    final live = rows.where((t) => t.deletedAt == null).toList();
    expect(live.single.id, work);
    expect(live.single.name, 'trip');
    expect(rows.where((t) => t.name.toLowerCase() == 'trip'), hasLength(1));
    expect(rows.singleWhere((t) => t.name == 'Work').deletedAt, isNotNull);
  });

  test(
    'renameTag onto a dead name stamps strictly after its tombstone',
    () async {
      // A tombstone from a peer whose clock runs ahead.
      final future = DateTime.now().toUtc().add(const Duration(seconds: 10));
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              name: 'Trip',
              lastModified: Value(future),
              deletedAt: Value(future),
            ),
          );
      final work = await tag('Work');

      await tags.renameTag(work, 'trip');

      final renamed = (await tags.getTagById(work))!;
      expect(renamed.name, 'trip');
      expect(renamed.lastModified.isAfter(future), isTrue);
    },
  );

  test('renameTag on a dead tag throws StateError', () async {
    final work = await tags.ensureTag('Work');
    await tags.deleteTag(work.id);

    await expectLater(tags.renameTag(work.id, 'Trip'), throwsStateError);
    final rows = await allTags();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Work');
  });

  test(
    'mergeTags into a dead keep tag throws StateError and writes nothing',
    () async {
      final keep = await tag('Keep');
      final merge = await tag('Merge');
      final n = await note();
      await ref(n, merge);
      await tags.deleteTag(keep);
      final keepBefore = (await tags.getTagById(keep))!;

      await expectLater(
        tags.mergeTags(keepId: keep, mergeId: merge),
        throwsStateError,
      );

      expect(await tagIdsOf(n), {merge});
      expect((await tags.getTagById(merge))!.deletedAt, isNull);
      expect((await tags.getTagById(keep))!, keepBefore);
      expect(
        (await noteRow(n)).lastModifiedDate!.isAtSameMomentAs(past),
        isTrue,
      );
    },
  );

  test('mergeTags from a dead merge tag throws StateError', () async {
    final keep = await tag('Keep');
    final merge = await tag('Merge');
    await tags.deleteTag(merge);

    await expectLater(
      tags.mergeTags(keepId: keep, mergeId: merge),
      throwsStateError,
    );
  });

  test(
    'mergeTags moves notes to the kept tag and tombstones the other',
    () async {
      final keep = await tag('Keep');
      final merge = await tag('Merge');
      final both = await note();
      final onlyMerge = await note();
      await ref(both, keep);
      await ref(both, merge);
      await ref(onlyMerge, merge);

      await tags.mergeTags(keepId: keep, mergeId: merge);

      expect(await tagIdsOf(both), {keep});
      expect(await tagIdsOf(onlyMerge), {keep});
      final refsToMerge = await (db.select(
        db.noteTagRefs,
      )..where((r) => r.tagId.equals(merge))).get();
      expect(refsToMerge, isEmpty);
      expect((await tags.getTagById(merge))!.deletedAt, isNotNull);
      expect(
        (await noteRow(onlyMerge)).lastModifiedDate!.isAfter(past),
        isTrue,
      );
      expect((await noteRow(both)).lastModifiedDate!.isAfter(past), isTrue);
    },
  );

  test('deleteTag removes refs, tombstones, bumps carriers', () async {
    final work = await tag('Work');
    final n = await note();
    await ref(n, work);

    await tags.deleteTag(work);

    expect(await tagIdsOf(n), isEmpty);
    final row = (await tags.getTagById(work))!;
    expect(row.deletedAt, isNotNull);
    expect(row.lastModified.isAfter(past), isTrue);
    expect((await noteRow(n)).lastModifiedDate!.isAfter(past), isTrue);
  });

  test('rename re-tags a soft-deleted note; usage excludes it', () async {
    final work = await tag('Work');
    final live = await note();
    final deleted = await note(deletedAt: past);
    await ref(live, work);
    await ref(deleted, work);

    await tags.renameTag(work, 'Trip');

    expect(await tagIdsOf(deleted), {work});
    expect((await noteRow(deleted)).lastModifiedDate!.isAfter(past), isTrue);
    final usage = await tags.watchTagUsage().first;
    expect(usage, [(id: work, name: 'Trip', noteCount: 1)]);
  });

  test('watchTagUsage lists zero-note tags and hides dead ones', () async {
    final b = await tag('beta');
    final a = await tag('Alpha');
    final gone = await tag('gone');
    await tags.deleteTag(gone);
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(name: 'off', isActivated: const Value(false)),
        );
    final n = await note();
    await ref(n, b);

    final usage = await tags.watchTagUsage().first;
    expect(usage, [
      (id: a, name: 'Alpha', noteCount: 0),
      (id: b, name: 'beta', noteCount: 1),
    ]);
  });
}
