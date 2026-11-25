import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/auth/owner_id.dart';
import 'package:hmm_console/core/data/local/database.dart';

void main() {
  test('counts live notes per author, ignoring deleted ones', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final a1 = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'a1'));
    final a2 = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'a2'));
    Future<void> note(int author, {bool deleted = false}) => db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            subject: 's',
            authorId: author,
            deletedAt: Value(deleted ? DateTime.now() : null),
          ),
        );
    await note(a2);
    await note(a2);
    await note(a2, deleted: true);
    await note(a1, deleted: true);

    expect(await noteCountsByAuthor(db), {a2: 2});
  });
}
