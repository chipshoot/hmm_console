import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/video/video_downloads.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/features/notes/presentation/widgets/video_menu.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _Files implements IVaultFileStore {
  _Files(this.target);
  final File target;
  @override
  Future<File?> localFile(String p) async =>
      target.existsSync() ? target : null;
  @override
  File? downloadTarget(String p) => target;
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  Future<void> offload(String p) async {}
}

class _Provider extends CloudSyncProvider {
  bool exists = true;
  bool largeOk = true;
  int existsCalls = 0;
  Completer<void>? holdDownload;
  @override
  bool get supportsLargeFiles => largeOk;

  int downloads = 0;
  Object? failWith;
  Future<void> Function(File target, TransferCancel? cancel)? body;

  @override
  Future<bool> largeFileExists(String path) async {
    existsCalls++;
    return exists;
  }

  @override
  Future<void> downloadLargeFile(
    String path,
    File target, {
    void Function(int received, int total)? onProgress,
    TransferCancel? cancel,
  }) async {
    downloads++;
    if (failWith != null) throw failWith!;
    if (holdDownload != null) await holdDownload!.future;
    onProgress?.call(50, 100);
    if (body != null) return body!(target, cancel);
    await target.writeAsBytes([1, 2, 3]);
    onProgress?.call(100, 100);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  // (tests below)
  late Directory dir;
  late File target;
  late _Provider provider;
  late ProviderContainer c;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vd');
    target = File('${dir.path}/v.mov');
    provider = _Provider();
    c = ProviderContainer(
      overrides: [
        vaultFileStoreProvider.overrideWith((ref) async => _Files(target)),
        videoCloudProvider.overrideWithValue(provider),
      ],
    );
    addTearDown(() {
      c.dispose();
      dir.deleteSync(recursive: true);
    });
  });

  test('fetch downloads to the offload target and reports progress', () async {
    final seen = <double>[];
    c.listen(videoDownloadsProvider, (_, n) {
      final v = n['p'];
      if (v != null) seen.add(v);
    });
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.ready);
    expect(r.file!.path, target.path);
    expect(target.existsSync(), isTrue);
    expect(seen, contains(0.5));
    expect(c.read(videoDownloadsProvider), isEmpty);
  });

  test('fetch returns still-uploading when the cloud lacks it', () async {
    provider.exists = false;
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.stillUploading);
    expect(r.file, isNull);
    expect(provider.downloads, 0);
  });

  test('a local file is returned without a download', () async {
    await target.writeAsBytes([9]);
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.ready);
    expect(provider.downloads, 0);
  });

  test('other errors are failed', () async {
    provider.failWith = StateError('https://secret');
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.failed);
    expect(c.read(videoDownloadsProvider), isEmpty);
  });

  test('cancelled download leaves no file', () async {
    provider.body = (t, cancel) async {
      await File('${t.path}.part').writeAsBytes([1]);
      c.read(videoDownloadsProvider.notifier).cancel('p');
      expect(cancel!.isCancelled, isTrue);
      await File('${t.path}.part').delete();
      throw const TransferCancelledException();
    };
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.cancelled);
    expect(target.existsSync(), isFalse);
    expect(File('${target.path}.part').existsSync(), isFalse);
    expect(c.read(videoDownloadsProvider), isEmpty);
  });
  test('concurrent fetches of one path share one download', () async {
    provider.holdDownload = Completer<void>();
    final n = c.read(videoDownloadsProvider.notifier);
    final a = n.fetch('p');
    final b = n.fetch('p');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    provider.holdDownload!.complete();
    final ra = await a;
    final rb = await b;
    expect(provider.downloads, 1);
    expect(ra.outcome, VideoFetchOutcome.ready);
    expect(rb.outcome, VideoFetchOutcome.ready);
    expect(rb.file!.path, ra.file!.path);
  });

  test('a provider without large-file support is never asked', () async {
    provider.largeOk = false;
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.failed);
    expect(provider.existsCalls, 0);
    expect(provider.downloads, 0);
  });

  test('menu helper waits for an active download instead of failing', () async {
    provider.holdDownload = Completer<void>();
    final n = c.read(videoDownloadsProvider.notifier);
    final tile = n.fetch('p');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final said = <String>[];
    final menu = videoFileOrFetch(
      lookupAppLocalizations(const Locale('en')),
      n,
      Future.value(_Files(target)),
      true,
      'p',
      said.add,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    provider.holdDownload!.complete();
    final f = await menu;
    await tile;
    expect(f?.path, target.path);
    expect(said, isEmpty);
    expect(provider.downloads, 1);
  });
}
