import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/owner_id.dart';
import '../local/database.dart';
import '../local/local_author_repository.dart';
import 'onedrive_graph_client.dart';

/// Owner folders exist under `approot/users/`, none is this device's, and
/// the app will not pick one by itself (several folders, or one folder while
/// this device already has notes): the person has to pick one (Settings).
class OneDriveFolderChoiceRequired implements Exception {
  const OneDriveFolderChoiceRequired(this.folders);

  final List<OneDriveUserFolder> folders;

  /// Shown as the sync error.
  static const syncMessage =
      'Hmm data found in OneDrive. Choose a folder in Settings.';

  @override
  String toString() => syncMessage;
}

/// Finds the folder under `approot/users/` that holds this device owner's
/// data, without needing a Hmm login.
///
/// 1. A folder named after the owner id → that one.
/// 2. Otherwise exactly one folder and no notes on this device → adopt it
///    (the owner id becomes its name). If the device has notes, the person
///    decides: [OneDriveFolderChoiceRequired] with that one folder.
/// 3. No folders → the owner id (the first write creates the folder).
/// 4. Several → [OneDriveFolderChoiceRequired]; [choose] settles it.
///
/// Adopting renames the owner's `Authors` row, so its id (and every note's
/// author id) stays the same, and clears the Hmm account link: the next Hmm
/// sign-in links afresh.
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

  /// Forgets the resolved folder and any pending folder choice. Call on
  /// every OneDrive sign-in and sign-out: another Microsoft account holds
  /// other folders, and a folder resolved on the old account must not be
  /// reused on the new one.
  void reset() {
    _resolved = null;
    _ref.read(oneDriveFolderChoiceProvider.notifier).clear();
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
    if (folders.length == 1 && !await _deviceHasNotes()) {
      final name = folders.single.name;
      await _adopt(name);
      return _found(name);
    }
    throw OneDriveFolderChoiceRequired(folders);
  }

  /// Any live note in the local database, whatever its author.
  Future<bool> _deviceHasNotes() async {
    final db = _ref.read(hmmDatabaseProvider);
    final row =
        await (db.select(db.notes)
              ..where((n) => n.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  String _found(String id) {
    _ref.read(oneDriveFolderChoiceProvider.notifier).clear();
    return id;
  }

  /// Makes [name] the owner id. The owner's `Authors` row is renamed so its
  /// id (and every note's author id) stays. When another row named [name]
  /// already exists it belongs to that folder's owner: no rename; the sync's
  /// orphan step then moves the old owner's notes onto it.
  ///
  /// The owner id and the row name must never disagree (the current author
  /// would resolve to a new, empty row and hide every note): the rename runs
  /// first and is undone if storing the owner id fails.
  Future<void> _adopt(String name) async {
    final store = await _ref.read(ownerIdStoreProvider.future);
    final current = await _ref.read(ownerIdProvider.future);
    // Joining a folder ends any link to a Hmm account. Harmless on its own
    // (the next sign-in links afresh), so it goes first.
    await store.clearLink();
    Author? renamed;
    final authors = _ref.read(localAuthorRepositoryProvider);
    // Case-sensitive: a name differing only by case is renamed too, so the
    // row keeps the adopted casing exactly.
    if (current != name) {
      final own = await authors.getAuthorByAccountName(current);
      // The lookup ignores case, so a "clash" with our own row is no clash.
      final other = await authors.getAuthorByAccountName(name);
      if (own != null && (other == null || other.id == own.id)) {
        await authors.updateAuthor(
          own.id,
          AuthorsCompanion(accountName: Value(name)),
        );
        renamed = own;
      }
    }
    try {
      await store.adoptOwnerId(name);
    } catch (_) {
      if (renamed != null) {
        await authors.updateAuthor(
          renamed.id,
          AuthorsCompanion(accountName: Value(renamed.accountName)),
        );
      }
      rethrow;
    }
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
