// Phase 3a: attachment refs (images + files) must survive the cloudStorage
// sync round-trip. Before this, _noteRowToBlob omitted the attachments column.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'onedrive_test_fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _attachmentsJson =
    '{"images":[],"files":[{"kind":"vault","path":"attachments/n/r.pdf",'
    '"contentType":"application/pdf","byteSize":3}]}';

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
    orchestrator = SyncOrchestrator(provider: provider, db: db, meta: meta, vaultStore: noopVaultStore);
  });

  tearDown(() async => db.close());

  test('outbound: pushed body carries the attachments JSON', () async {
    final id = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'p', authorId: 1,
          attachments: const Value(_attachmentsJson),
        ));
    final note =
        await (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();
    provider.remoteManifest = SyncManifest(
        version: 1, generatedAt: DateTime.utc(2026, 1, 1),
        deviceId: 't', notes: const [], attachments: const []);

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    expect(provider.pushed[note.uuid]!['attachments'] as String,
        contains('r.pdf'));
  });

  test('inbound insert applies the attachments JSON', () async {
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
      'attachments': _attachmentsJson,
      'tags': const <String>[],
    };

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    final row = await (db.select(db.notes)..where((x) => x.uuid.equals(uuid)))
        .getSingleOrNull();
    final atts = NoteAttachmentsCodec.decode(row!.attachments);
    expect(atts.files.single, isA<VaultRef>());
    expect((atts.files.single as VaultRef).path, 'attachments/n/r.pdf');
  });

  test('inbound update omitting attachments preserves the stored value',
      () async {
    final local = DateTime.utc(2026, 1, 1);
    final id = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'm', authorId: 1, uuid: const Value('n1'),
          createDate: Value(local), lastModifiedDate: Value(local),
          attachments: const Value(_attachmentsJson),
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
    final row =
        await (db.select(db.notes)..where((x) => x.id.equals(id))).getSingle();
    expect(row.subject, 'm2');
    final atts = NoteAttachmentsCodec.decode(row.attachments);
    expect(atts.files.length, 1,
        reason: 'omitted attachments must not be cleared');
  });
}

class _FakeProvider extends CloudSyncProvider {
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
