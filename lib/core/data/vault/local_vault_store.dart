// LocalVaultStore — files-on-disk backing for IVaultStore.
//
// Same code is used for both the `local` tier (root under the app's
// documents directory) and the `cloudStorage` tier (root inside the
// user's OneDrive / iCloud Drive folder). The OS-level sync client
// is responsible for replicating those bytes across devices; this
// store doesn't know or care which tier it's running in.

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../attachments/video_attachment.dart' show isVideoVaultPath;
import 'sensitive_path.dart';
import 'vault_file_store.dart';
import 'vault_path.dart';
import 'vault_store.dart';

class LocalVaultStore implements IVaultStore, IVaultFileStore {
  /// [rootDir] is the absolute path on disk where the vault's
  /// `attachments/` tree lives. The directory will be created lazily
  /// on the first write.
  ///
  /// [offloadDir] is a second root, outside any backup, that holds videos
  /// already uploaded to the cloud. Null means videos only ever live under
  /// [rootDir].
  LocalVaultStore({required Directory rootDir, Directory? offloadDir})
      : _rootDir = rootDir,
        _offloadDir = offloadDir;

  final Directory _rootDir;
  final Directory? _offloadDir;

  /// Exposed for diagnostics; callers should never join paths
  /// against this directly — use the store's API.
  Directory get rootDir => _rootDir;

  File _fileFor(String relativePath) {
    vaultRelativePathValidate(relativePath);
    // p.joinAll splits on '/' which is what the spec mandates; we
    // pass segments individually so the OS layer can apply its own
    // separator on Windows.
    final segments = relativePath.split('/');
    return File(p.joinAll([_rootDir.path, ...segments]));
  }

  File? _offloadFileFor(String relativePath) {
    final dir = _offloadDir;
    if (dir == null || !isVideoVaultPath(relativePath)) return null;
    vaultRelativePathValidate(relativePath);
    return File(p.joinAll([dir.path, ...relativePath.split('/')]));
  }

  @override
  File? downloadTarget(String relativePath) => _offloadFileFor(relativePath);

  @override
  Future<List<VaultEntry>> listOffloaded() async {
    final dir = _offloadDir;
    if (dir == null || !await dir.exists()) return const [];
    final all = await _listRoot(dir, '');
    return all
        .where((e) => isVideoVaultPath(e.relativePath))
        .where((e) => !e.relativePath.endsWith('.part'))
        .toList();
  }

  @override
  Future<void> deleteOffloaded(String relativePath) async {
    final f = _offloadFileFor(relativePath);
    if (f != null && await f.exists()) await f.delete();
  }

  @override
  Future<DateTime?> offloadedModified(String relativePath) async {
    final f = _offloadFileFor(relativePath);
    if (f == null || !await f.exists()) return null;
    return f.lastModified();
  }

  @override
  Future<int> deleteStaleParts() async {
    final dir = _offloadDir;
    if (dir == null || !await dir.exists()) return 0;
    var n = 0;
    await for (final e in dir.list(recursive: true)) {
      if (e is File && e.path.endsWith('.part')) {
        await e.delete();
        n++;
      }
    }
    return n;
  }

  @override
  Future<void> offload(String relativePath) async {
    vaultRelativePathValidate(relativePath);
    if (!isVideoVaultPath(relativePath)) {
      throw ArgumentError.value(
          relativePath, 'relativePath', 'only videos can be offloaded');
    }
    final target = _offloadFileFor(relativePath);
    if (target == null) {
      throw StateError('no offload root configured');
    }
    final source = _fileFor(relativePath);
    if (!await source.exists()) {
      if (await target.exists()) return;
      throw VaultStoreException('file not found', relativePath);
    }
    await target.parent.create(recursive: true);
    try {
      await source.rename(target.path);
      return;
    } on FileSystemException {
      // Different volume: fall through to copy + rename.
    }
    final tmp = File('${target.path}.tmp');
    try {
      await source.copy(tmp.path);
      await tmp.rename(target.path);
    } catch (_) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {
          // Swallow — original error is more important.
        }
      }
      rethrow;
    }
    await source.delete();
  }

  @override
  Future<void> putBytes(
    String relativePath,
    Uint8List bytes, {
    String? contentType,
  }) async {
    final target = _fileFor(relativePath);
    await target.parent.create(recursive: true);

    // Atomic-replace: write to a sibling .tmp file then rename. This
    // keeps OneDrive (and any backup that scans the dir) from ever
    // observing a half-written file.
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      await tmp.rename(target.path);
    } catch (_) {
      // Best-effort cleanup of the tmp file on rename failure so a
      // failed write doesn't leave litter behind.
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {
          // Swallow — original error is more important.
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> importFile(String relativePath, File source) async {
    final target = _fileFor(relativePath);
    if (isSensitiveVaultPath(relativePath)) {
      throw ArgumentError.value(
          relativePath, 'relativePath', 'sensitive paths cannot be imported');
    }
    if (!await source.exists()) {
      throw VaultStoreException('source file not found', relativePath);
    }
    await target.parent.create(recursive: true);
    try {
      await source.rename(target.path);
      return;
    } on FileSystemException {
      // Different volume: fall through to copy + rename.
    }
    final tmp = File('${target.path}.tmp');
    try {
      await source.copy(tmp.path);
      await tmp.rename(target.path);
    } catch (_) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {
          // Swallow — original error is more important.
        }
      }
      rethrow;
    }
    await source.delete();
  }

  @override
  Future<File?> localFile(String relativePath) async {
    final f = _fileFor(relativePath);
    if (await f.exists()) return f;
    final off = _offloadFileFor(relativePath);
    return off != null && await off.exists() ? off : null;
  }

  @override
  Future<Uint8List> getBytes(String relativePath) async {
    final f = _fileFor(relativePath);
    if (!await f.exists()) {
      throw VaultStoreException('file not found', relativePath);
    }
    return Uint8List.fromList(await f.readAsBytes());
  }

  @override
  Future<bool> exists(String relativePath) async {
    if (await _fileFor(relativePath).exists()) return true;
    final off = _offloadFileFor(relativePath);
    return off != null && await off.exists();
  }

  @override
  Future<void> delete(String relativePath) async {
    final f = _fileFor(relativePath);
    if (await f.exists()) {
      await f.delete();
    }
    final off = _offloadFileFor(relativePath);
    if (off != null && await off.exists()) {
      await off.delete();
    }
  }

  @override
  Future<List<VaultEntry>> list(String prefix) async {
    final results = await _listRoot(_rootDir, prefix);
    final offload = _offloadDir;
    if (offload == null) return results;
    final seen = results.map((e) => e.relativePath).toSet();
    final extra = (await _listRoot(offload, prefix))
        .where((e) => isVideoVaultPath(e.relativePath))
        .where((e) => !seen.contains(e.relativePath));
    if (extra.isEmpty) return results;
    return [...results, ...extra]
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
  }

  Future<List<VaultEntry>> _listRoot(Directory root, String prefix) async {
    // Empty prefix == list everything under the root.
    Directory scanRoot;
    String relPrefix;
    if (prefix.isEmpty) {
      scanRoot = root;
      relPrefix = '';
    } else {
      vaultRelativePathValidate(prefix);
      final segments = prefix.split('/');
      final candidate =
          Directory(p.joinAll([root.path, ...segments]));
      if (await candidate.exists()) {
        scanRoot = candidate;
        relPrefix = prefix;
      } else {
        // Prefix might address a single file rather than a folder.
        final asFile = File(p.joinAll([root.path, ...segments]));
        if (await asFile.exists()) {
          final stat = await asFile.stat();
          return [
            VaultEntry(relativePath: prefix, byteSize: stat.size),
          ];
        }
        return const [];
      }
    }

    if (!await scanRoot.exists()) return const [];

    final results = <VaultEntry>[];
    final rootPathLen = root.path.length;
    await for (final entity in scanRoot.list(recursive: true)) {
      if (entity is! File) continue;
      // Skip half-written .tmp files left by an interrupted write.
      if (entity.path.endsWith('.tmp')) continue;
      final stat = await entity.stat();
      // Convert absolute path → vault-relative POSIX path.
      final raw = entity.path.substring(rootPathLen);
      final trimmed = raw.startsWith(Platform.pathSeparator)
          ? raw.substring(1)
          : raw;
      final posix = trimmed.replaceAll(r'\', '/');
      // Final defensive check: the assembled relative path must
      // validate. If it doesn't (e.g. a stray file with disallowed
      // chars dropped in by a user), silently skip — we don't
      // surface anything we couldn't have produced ourselves.
      try {
        vaultRelativePathValidate(posix);
      } on ArgumentError {
        continue;
      }
      // Guard against pathological prefixes that don't match (e.g.
      // case differences on case-insensitive FS): only include
      // entries whose normalised path actually starts with the
      // requested prefix.
      if (relPrefix.isNotEmpty &&
          !(posix == relPrefix || posix.startsWith('$relPrefix/'))) {
        continue;
      }
      results.add(VaultEntry(relativePath: posix, byteSize: stat.size));
    }

    // Stable ordering so callers can rely on it for snapshot tests
    // and incremental sync diffs.
    results.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return results;
  }
}
