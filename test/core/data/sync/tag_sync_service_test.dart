import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/tag_sync_service.dart';

Map<String, dynamic> _tag(String name,
        {String? desc, bool active = true, required String lm, bool deleted = false}) =>
    {
      'name': name,
      'description': desc,
      'is_activated': active,
      'last_modified': lm,
      'deleted': deleted,
    };

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

  test('remote-newer definition is applied locally', () async {
    await repo.upsertTagByName('work',
        description: 'old', isActivated: true,
        lastModified: DateTime.utc(2026, 1, 1));
    await svc.mergeDefinitions(
      {'tags': [_tag('work', desc: 'new', lm: '2026-02-01T00:00:00Z')]},
      deviceId: 'dev', now: DateTime.utc(2026, 3, 1),
    );
    final tags = await repo.getTagsWithMeta();
    expect(tags.single.description, 'new');
  });

  test('local-newer definition is kept and pushed', () async {
    await repo.upsertTagByName('work',
        description: 'local', isActivated: true,
        lastModified: DateTime.utc(2026, 5, 1));
    final doc = await svc.mergeDefinitions(
      {'tags': [_tag('work', desc: 'remote', lm: '2026-01-01T00:00:00Z')]},
      deviceId: 'dev', now: DateTime.utc(2026, 6, 1),
    );
    expect((await repo.getTagsWithMeta()).single.description, 'local');
    final pushed = (doc['tags'] as List).single as Map;
    expect(pushed['description'], 'local');
  });

  test('remote tombstone propagates', () async {
    await repo.upsertTagByName('work',
        isActivated: true, lastModified: DateTime.utc(2026, 1, 1));
    await svc.mergeDefinitions(
      {'tags': [_tag('work', lm: '2026-02-01T00:00:00Z', deleted: true)]},
      deviceId: 'dev', now: DateTime.utc(2026, 3, 1),
    );
    expect((await repo.getTagsWithMeta()).single.deletedAt, isNotNull);
  });

  test('same name from two devices stays one tag', () async {
    await repo.upsertTagByName('work',
        isActivated: true, lastModified: DateTime.utc(2026, 1, 1));
    await svc.mergeDefinitions(
      {'tags': [_tag('WORK', lm: '2026-02-01T00:00:00Z')]},
      deviceId: 'dev', now: DateTime.utc(2026, 3, 1),
    );
    expect((await repo.getTagsWithMeta()).length, 1);
  });

  test('null/malformed remote doc does not throw and pushes local', () async {
    await repo.upsertTagByName('work',
        isActivated: true, lastModified: DateTime.utc(2026, 1, 1));
    final doc = await svc.mergeDefinitions(null,
        deviceId: 'dev', now: DateTime.utc(2026, 3, 1));
    expect((doc['tags'] as List).length, 1);
  });
}
