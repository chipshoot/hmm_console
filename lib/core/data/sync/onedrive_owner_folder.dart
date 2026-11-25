import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/owner_id.dart';
import '../local/database.dart';
import '../local/local_author_repository.dart';
import 'onedrive_graph_client.dart';

/// Several owner folders exist under `approot/users/` and none is this
/// device's: the person has to pick one (Settings).
class OneDriveFolderChoiceRequired implements Exception {
  const OneDriveFolderChoiceRequired(this.folders);

  final List<OneDriveUserFolder> folders;

  /// Shown as the sync error.
  static const syncMessage =
      'Several Hmm data folders found in OneDrive. Choose one in Settings.';

  @override
  String toString() => syncMessage;
}

/// Finds the folder under `approot/users/` that holds this device owner's
/// data, without needing a Hmm login.
///
/// 1. A folder named after the owner id → that one.
/// 2. Otherwise exactly one folder → adopt it (the owner id becomes its name).
/// 3. No folders → the owner id (the first write creates the folder).
/// 4. Several → [OneDriveFolderChoiceRequired]; [choose] settles it.
///
/// Adopting renames the owner's `Authors` row, so its id (and every note's
/// author id) stays the same.
class OneDriveOwnerFolder {
  OneDriveOwnerFolder(this._ref);

  final Ref _ref;
  Future<String>? _resolved;

  /// The owner folder id. Memoised until [choose]; a failure is not cached.
  Future<String> resolve() {
    return _resolved ??= _resolve().catchError((Object e, StackTrace st) {
      _resolved = null;
      if (e is OneDriveFolderChoiceRequired) {
        _ref.read(oneDriveFolderChoiceProvider.notifier).set(e.folders);
      }
      Error.throwWithStackTrace(e, st);
    });
  }

  /// Uses the folder [name] from now on.
  Future<void> choose(String name) async {
    await _adopt(name);
    _resolved = Future.value(name);
    _ref.read(oneDriveFolderChoiceProvider.notifier).clear();
  }

  Future<String> _resolve() async {
    final graph = _ref.read(oneDriveGraphClientProvider);
    final ownerId = await _ref.read(ownerIdProvider.future);
    if (await graph.userFolderExists(ownerId)) return _found(ownerId);
    final folders = await graph.listUserFolders();
    if (folders.isEmpty) return _found(ownerId);
    if (folders.length == 1) {
      final name = folders.single.name;
      await _adopt(name, known: folders.single);
      return _found(name);
    }
    throw OneDriveFolderChoiceRequired(folders);
  }

  String _found(String id) {
    _ref.read(oneDriveFolderChoiceProvider.notifier).clear();
    return id;
  }

  Future<void> _adopt(String name, {OneDriveUserFolder? known}) async {
    final store = await _ref.read(ownerIdStoreProvider.future);
    final current = await _ref.read(ownerIdProvider.future);
    if (current.toLowerCase() != name.toLowerCase()) {
      final authors = _ref.read(localAuthorRepositoryProvider);
      if (await authors.getAuthorByAccountName(name) != null) {
        final folder =
            known ??
            _ref
                .read(oneDriveFolderChoiceProvider)
                ?.where((f) => f.name == name)
                .firstOrNull ??
            (name: name, modified: null);
        throw OneDriveFolderChoiceRequired([folder]);
      }
      final own = await authors.getAuthorByAccountName(current);
      if (own != null) {
        await authors.updateAuthor(
          own.id,
          AuthorsCompanion(accountName: Value(name)),
        );
      }
    }
    await store.adoptOwnerId(name);
    _ref.invalidate(ownerIdProvider);
  }
}

final oneDriveOwnerFolderProvider = Provider<OneDriveOwnerFolder>(
  OneDriveOwnerFolder.new,
);

/// The folders to choose from, set when [OneDriveOwnerFolder.resolve] throws
/// [OneDriveFolderChoiceRequired]; null otherwise.
class OneDriveFolderChoiceNotifier extends Notifier<List<OneDriveUserFolder>?> {
  @override
  List<OneDriveUserFolder>? build() => null;

  void set(List<OneDriveUserFolder> folders) =>
      state = List.unmodifiable(folders);

  void clear() => state = null;
}

final oneDriveFolderChoiceProvider =
    NotifierProvider<OneDriveFolderChoiceNotifier, List<OneDriveUserFolder>?>(
      OneDriveFolderChoiceNotifier.new,
    );
