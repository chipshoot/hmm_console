import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'onedrive_test_fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProvider extends CloudSyncProvider {
  _FakeProvider(this.tagsToReturn);
  final Map<String, dynamic>? tagsToReturn;
  Map<String, dynamic>? pushedTags;
  bool throwOnPullTags = false;

  @override
  Future<Map<String, dynamic>?> pullTags() async {
    if (throwOnPullTags) throw Exception('boom');
    return tagsToReturn;
  }

  @override
  Future<void> pushTags(Map<String, dynamic> doc) async => pushedTags = doc;

  @override
  Future<SyncManifest?> pullManifest() async => SyncManifest(
      version: 1,
      generatedAt: DateTime.utc(2026),
      deviceId: 'remote',
      notes: const [],
      attachments: const []);

  @override
  Future<void> pushManifest(SyncManifest manifest) async {}

  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;

  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}

  @override
  String get providerId => 'fake';

  @override
  Future<bool> isAuthenticated() async => true;

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;

  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  SyncOrchestrator orch(CloudSyncProvider p) => SyncOrchestrator(
      provider: p, db: db, meta: SyncMetaRepository(), vaultStore: noopVaultStore);

  test('remote tag is merged locally and merged doc is pushed', () async {
    final provider = _FakeProvider({
      'tags': [
        {
          'name': 'work',
          'description': 'd',
          'is_activated': true,
          'last_modified': '2026-05-01T00:00:00Z',
          'deleted': false
        }
      ]
    });
    await orch(provider).syncNow();

    final tags = await LocalTagRepository(db).getTagsWithMeta();
    expect(tags.map((t) => t.name), contains('work'));
    expect(provider.pushedTags, isNotNull);
  });

  test('a pullTags failure is non-fatal (sync still completes)', () async {
    final provider = _FakeProvider(null)..throwOnPullTags = true;
    final result = await orch(provider).syncNow();
    expect(result.errors.any((e) => e.recordType == 'tags'), isTrue);
  });
}
