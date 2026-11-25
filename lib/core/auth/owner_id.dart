import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/providers/current_user_provider.dart';
import '../data/local/database.dart';
import '../data/local/local_author_repository.dart';
import '../network/idp_token_service.dart';
import '../util/uuid.dart';

/// Persists the device owner id: the stable key local data is stored under,
/// independent of whether anyone is signed in. Also remembers which Hmm
/// account (if any) the device was last linked to.
class OwnerIdStore {
  OwnerIdStore(this._prefs);

  final SharedPreferences _prefs;

  static const _ownerKey = 'hmm.ownerId';
  static const _linkSubKey = 'hmm.linkedHmmSub';
  static const _linkEmailKey = 'hmm.linkedHmmEmail';

  String? get ownerId => _prefs.getString(_ownerKey);

  /// Stores the id the first time. Throws [StateError] if one already exists.
  Future<void> setOwnerIdOnce(String id) async {
    if (ownerId != null) {
      throw StateError('Owner id is already set to $ownerId');
    }
    await _prefs.setString(_ownerKey, id);
  }

  /// The only overwrite of an existing owner id (used by account adoption).
  Future<void> adoptOwnerId(String id) => _prefs.setString(_ownerKey, id);

  String? get linkedHmmSub => _prefs.getString(_linkSubKey);
  String? get linkedHmmEmail => _prefs.getString(_linkEmailKey);

  Future<void> setLink(String sub, String? email) async {
    await _prefs.setString(_linkSubKey, sub);
    if (email == null) {
      await _prefs.remove(_linkEmailKey);
    } else {
      await _prefs.setString(_linkEmailKey, email);
    }
  }
}

/// Resolves the device owner id, storing it on first use. Order: stored id,
/// signed-in sub, sub of the stored (possibly expired) token, the active
/// author row (most notes wins, ties to the lowest id), else a new UUID.
Future<String> resolveOwnerId({
  required OwnerIdStore store,
  required String? signedInSub,
  String? signedInEmail,
  required Future<String?> Function() peekStoredSub,
  required Future<String?> Function() peekStoredEmail,
  required IAuthorRepository authors,
  required Future<Map<int, int>> Function() noteCountsByAuthor,
  required String Function() newId,
}) async {
  final stored = store.ownerId;
  if (stored != null) return stored;

  String? id;
  var linked = false;

  if (signedInSub != null) {
    id = signedInSub;
    linked = true;
  } else {
    final peeked = await peekStoredSub();
    if (peeked != null) {
      id = peeked;
      linked = true;
    }
  }

  if (id == null) {
    final rows = await authors.getAuthors();
    if (rows.length == 1) {
      id = rows.single.accountName;
    } else if (rows.length > 1) {
      final counts = await noteCountsByAuthor();
      final sorted = [...rows]
        ..sort((a, b) {
          final byNotes = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
          return byNotes != 0 ? byNotes : a.id.compareTo(b.id);
        });
      id = sorted.first.accountName;
    }
    linked = id != null;
  }

  id ??= newId();
  await store.setOwnerIdOnce(id);
  if (linked) await store.setLink(id, signedInEmail ?? await peekStoredEmail());
  return id;
}

final ownerIdStoreProvider = FutureProvider<OwnerIdStore>((ref) async {
  return OwnerIdStore(await SharedPreferences.getInstance());
});

/// The resolved device owner id. Reads the signed-in user once (no watch):
/// the id must not follow a later login.
final ownerIdProvider = FutureProvider<String>((ref) async {
  final store = await ref.watch(ownerIdStoreProvider.future);
  final user = ref.read(currentUserProvider);
  final idp = ref.read(idpTokenServiceProvider);
  final db = ref.read(hmmDatabaseProvider);
  return resolveOwnerId(
    store: store,
    signedInSub: user?.uid,
    signedInEmail: user?.email,
    peekStoredSub: idp.peekStoredSub,
    peekStoredEmail: idp.peekStoredEmail,
    authors: ref.read(localAuthorRepositoryProvider),
    noteCountsByAuthor: () => noteCountsByAuthor(db),
    newId: generateUuid,
  );
});

/// Live (non-deleted) note count per author id.
Future<Map<int, int>> noteCountsByAuthor(HmmDatabase db) async {
  final count = db.notes.id.count();
  final query = db.selectOnly(db.notes)
    ..addColumns([db.notes.authorId, count])
    ..where(db.notes.deletedAt.isNull())
    ..groupBy([db.notes.authorId]);
  final rows = await query.get();
  return {for (final r in rows) r.read(db.notes.authorId)!: r.read(count) ?? 0};
}
