import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('subsystemAnchorUuid is deterministic', () {
    expect(subsystemAnchorUuid('automobile'), subsystemAnchorUuid('automobile'));
    expect(subsystemAnchorUuid('automobile'), isNot(subsystemAnchorUuid('health')));
  });

  test('automobileAnchorProvider is idempotent (one anchor, stable uuid)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    final author = await db.select(db.authors).getSingle();
    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      localHmmNoteRepositoryProvider
          .overrideWithValue(LocalHmmNoteRepository(db, () async => author)),
    ]);
    addTearDown(container.dispose);

    final first = await container.read(automobileAnchorProvider.future);
    container.invalidate(automobileAnchorProvider);
    final second = await container.read(automobileAnchorProvider.future);

    expect(first.uuid, subsystemAnchorUuid('automobile'));
    expect(second.id, first.id);
    final anchors = await container.read(subsystemAnchorsProvider.future);
    expect(anchors.map((a) => a.subject), ['Automobile']);
  });
}
