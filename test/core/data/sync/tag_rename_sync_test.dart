import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/tag_sync_service.dart';

void main() {
  late HmmDatabase db;
  late LocalTagRepository repo;
  late TagSyncService svc;

  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalTagRepository(db);
    svc = TagSyncService(repo);
  });
  tearDown(() => db.close());

  Future<Map<String, dynamic>> renameWorkToTrip() async {
    final work = await repo.ensureTag('Work');
    await repo.renameTag(work.id, 'Trip');
    return svc.mergeDefinitions(
      null,
      deviceId: 'a',
      now: DateTime.now().toUtc(),
    );
  }

  Map<String, Map> byName(Map<String, dynamic> doc) => {
    for (final t in (doc['tags'] as List).cast<Map>()) t['name'] as String: t,
  };

  test(
    'rename produces a new-name record and an old-name tombstone in tags.json',
    () async {
      final now = DateTime.now().toUtc();
      final renameTime = DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      );
      final records = byName(await renameWorkToTrip());

      expect(records['Trip']!['deleted'], false);
      expect(records['Work']!['deleted'], true);
      final tombLm = DateTime.parse(
        records['Work']!['last_modified'] as String,
      );
      expect(tombLm.isBefore(renameTime), isFalse);
    },
  );

  test(
    'a peer applying that document ends with only the new name live',
    () async {
      final doc = await renameWorkToTrip();

      final peerDb = HmmDatabase(NativeDatabase.memory());
      addTearDown(peerDb.close);
      final peer = LocalTagRepository(peerDb);
      await peerDb
          .into(peerDb.tags)
          .insert(
            TagsCompanion.insert(
              name: 'Work',
              lastModified: Value(DateTime.utc(2026, 1, 1)),
            ),
          );

      await TagSyncService(
        peer,
      ).mergeDefinitions(doc, deviceId: 'b', now: DateTime.now().toUtc());

      final live = await peer.watchLiveTagNames().first;
      expect(live.values, ['Trip']);
    },
  );
}
