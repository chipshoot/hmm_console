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

import 'vault_path.dart';
import 'vault_store.dart';

class LocalVaultStore implements IVaultStore {
  /// [rootDir] is the absolute path on disk where the vault's
  /// `attachments/` tree lives. The directory will be created lazily
  /// on the first write.
  LocalVaultStore({required Directory rootDir}) : _rootDir = rootDir;

  final Directory _rootDir;

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
  Future<Uint8List> getBytes(String relativePath) async {
    final f = _fileFor(relativePath);
    if (!await f.exists()) {
      throw VaultStoreException('file not found', relativePath);
    }
    return Uint8List.fromList(await f.readAsBytes());
  }

  @override
  Future<bool> exists(String relativePath) async {
    return _fileFor(relativePath).exists();
  }

  @override
  Future<void> delete(String relativePath) async {
    final f = _fileFor(relativePath);
    if (await f.exists()) {
      await f.delete();
    }
  }

  @override
  Future<List<VaultEntry>> list(String prefix) async {
    // Empty prefix == list everything under the root.
    Directory scanRoot;
    String relPrefix;
    if (prefix.isEmpty) {
      scanRoot = _rootDir;
      relPrefix = '';
    } else {
      vaultRelativePathValidate(prefix);
      final segments = prefix.split('/');
      final candidate =
          Directory(p.joinAll([_rootDir.path, ...segments]));
      if (await candidate.exists()) {
        scanRoot = candidate;
        relPrefix = prefix;
      } else {
        // Prefix might address a single file rather than a folder.
        final asFile = File(p.joinAll([_rootDir.path, ...segments]));
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
    final rootPathLen = _rootDir.path.length;
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
