import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late HmmDatabase db;
  late _FakeProvider provider;
  late SyncOrchestrator orchestrator;
  late SyncMetaRepository meta;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    provider = _FakeProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(provider: provider, db: db, meta: meta);
  });

  tearDown(() async => db.close());

  test('outbound: pushed body carries the location trio', () async {
    final id = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'p', authorId: 1,
          latitude: const Value(47.6),
          longitude: const Value(-122.3),
          locationLabel: const Value('Seattle, WA'),
        ));
    final note =
        await (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();
    provider.remoteManifest = SyncManifest(
        version: 1, generatedAt: DateTime.utc(2026, 1, 1),
        deviceId: 't', notes: const [], attachments: const []);

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    final body = provider.pushed[note.uuid]!;
    expect(body['latitude'], 47.6);
    expect(body['longitude'], -122.3);
    expect(body['locationLabel'], 'Seattle, WA');
  });

  test('inbound insert applies the location trio', () async {
    const uuid = 'r1';
    final t = DateTime.utc(2026, 2, 2);
    provider.remoteManifest = SyncManifest(
        version: 1, generatedAt: t, deviceId: 'o',
        notes: [ManifestEntry(id: uuid, updatedAt: t, deleted: false)],
        attachments: const []);
    provider.remoteBodies[uuid] = {
      'uuid': uuid, 'subject': 'x',
      'createDate': t.toIso8601String(),
      'lastModifiedDate': t.toIso8601String(),
      'latitude': 1.5, 'longitude': 2.5, 'locationLabel': 'Z',
      'tags': const <String>[],
    };

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    final n = await (db.select(db.notes)..where((x) => x.uuid.equals(uuid)))
        .getSingleOrNull();
    expect(n!.latitude, 1.5);
    expect(n.longitude, 2.5);
    expect(n.locationLabel, 'Z');
  });

  test('inbound update omitting location preserves stored value', () async {
    final local = DateTime.utc(2026, 1, 1);
    final id = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'm', authorId: 1, uuid: const Value('n1'),
          createDate: Value(local), lastModifiedDate: Value(local),
          latitude: const Value(9.0), longitude: const Value(8.0),
          locationLabel: const Value('Keep'),
        ));
    final remote = local.add(const Duration(days: 1));
    provider.remoteManifest = SyncManifest(
        version: 1, generatedAt: remote, deviceId: 'o',
        notes: [ManifestEntry(id: 'n1', updatedAt: remote, deleted: false)],
        attachments: const []);
    provider.remoteBodies['n1'] = {
      'uuid': 'n1', 'subject': 'm2',
      'createDate': local.toIso8601String(),
      'lastModifiedDate': remote.toIso8601String(),
      'tags': const <String>[],
    };

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    final n =
        await (db.select(db.notes)..where((x) => x.id.equals(id))).getSingle();
    expect(n.subject, 'm2');
    expect(n.latitude, 9.0, reason: 'omitted location must not be zeroed');
    expect(n.locationLabel, 'Keep');
  });
}

class _FakeProvider implements CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> pushed = {};
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => remoteManifest;
  @override
  Future<void> pushManifest(SyncManifest m) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async =>
      remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async =>
      pushed[id] = body;
  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;
  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullTags() async => null;
  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {}
}
