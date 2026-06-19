import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';

void main() {
  test('v6 schema: Tags carries lastModified + deletedAt', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // v7 added Notes.noteDate; the tag sync columns from v6 are unchanged.
    expect(db.schemaVersion, 7);

    final id = await db.into(db.tags).insert(
          TagsCompanion.insert(name: 'work'),
        );
    final fresh = await (db.select(db.tags)..where((t) => t.id.equals(id)))
        .getSingle();
    expect(fresh.deletedAt, isNull);
    expect(fresh.lastModified, isA<DateTime>());

    final when = DateTime.utc(2026, 6, 1);
    await (db.update(db.tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(deletedAt: Value(when), lastModified: Value(when)),
    );
    final after = await (db.select(db.tags)..where((t) => t.id.equals(id)))
        .getSingle();
    expect(after.deletedAt!.isAtSameMomentAs(when), isTrue);
    expect(after.lastModified.isAtSameMomentAs(when), isTrue);
  });
}
