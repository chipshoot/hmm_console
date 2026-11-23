import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:hmm_console/core/data/sync/onedrive_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

/// A OneDrive provider whose remote is empty and healthy, except that the
/// one-time legacy migration throws (as a dropped connection does).
class _MigrationFailsProvider extends OneDriveSyncProvider {
  _MigrationFailsProvider()
    : super(
        FakeOneDriveAuth(),
        OneDriveGraphClient(
          FakeOneDriveAuth(),
          () async => 'USER-A',
          dio: Dio(),
        ),
        _NoIdp(),
      );

  @override
  Future<int> migrateLegacyIfNeeded() async =>
      throw Exception('HttpException: read failed');

  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<SyncManifest?> pullManifest() async => null;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;
  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullTags() async => null;
  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteStates() async => null;
  @override
  Future<void> pushNoteStates(
    Map<String, dynamic> doc, {
    required Set<String> changed,
  }) async {}
  @override
  bool get supportsAttachments => false;
  @override
  bool get supportsLargeFiles => false;
  @override
  Future<void> pushAttachment(String path, Uint8List bytes) async {}
  @override
  Future<Uint8List?> pullAttachment(String path) async => null;
  @override
  Future<Set<String>> listAttachmentPaths() async => const {};
}

class _NoIdp implements IdpTokenService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test(
    'a legacy-migration failure does not hold the note cursor back',
    () async {
      final provider = _MigrationFailsProvider();
      final meta = SyncMetaRepository();
      final result = await SyncOrchestrator(
        provider: provider,
        db: db,
        meta: meta,
        vaultStore: noopVaultStore,
      ).syncNow();

      // Still reported, so the sync card shows it.
      expect(
        result.errors.where((e) => e.recordId == 'legacy-migration'),
        hasLength(1),
      );
      expect(
        result.errors.every((e) => e.recordId == 'legacy-migration'),
        isTrue,
        reason: 'the rest of the sync was clean: ${result.errors}',
      );
      expect(await meta.getLastPushedAt('onedrive'), result.completedAt);
    },
  );
}
