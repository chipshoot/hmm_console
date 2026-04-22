import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

abstract interface class IAuthorRepository {
  Future<List<Author>> getAuthors();

  Future<Author?> getAuthorById(int id);

  Future<Author?> getAuthorByAccountName(String accountName);

  Future<Author> createAuthor(AuthorsCompanion author);

  Future<Author> updateAuthor(int id, AuthorsCompanion author);

  Future<void> deactivateAuthor(int id);

  Future<Author> getOrCreateDefaultAuthor(String accountName);
}

class LocalAuthorRepository implements IAuthorRepository {
  LocalAuthorRepository(this._db);

  final HmmDatabase _db;

  @override
  Future<List<Author>> getAuthors() async {
    return await (_db.select(_db.authors)
          ..where((a) => a.isActivated.equals(true)))
        .get();
  }

  @override
  Future<Author?> getAuthorById(int id) async {
    return await (_db.select(_db.authors)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<Author?> getAuthorByAccountName(String accountName) async {
    return await (_db.select(_db.authors)
          ..where((a) => a.accountName.lower().equals(accountName.toLowerCase().trim())))
        .getSingleOrNull();
  }

  @override
  Future<Author> createAuthor(AuthorsCompanion author) async {
    final id = await _db.into(_db.authors).insert(author);
    return (await getAuthorById(id))!;
  }

  @override
  Future<Author> updateAuthor(int id, AuthorsCompanion author) async {
    await (_db.update(_db.authors)..where((a) => a.id.equals(id)))
        .write(author);
    return (await getAuthorById(id))!;
  }

  @override
  Future<void> deactivateAuthor(int id) async {
    await (_db.update(_db.authors)..where((a) => a.id.equals(id)))
        .write(const AuthorsCompanion(isActivated: Value(false)));
  }

  @override
  Future<Author> getOrCreateDefaultAuthor(String accountName) async {
    final existing = await getAuthorByAccountName(accountName);
    if (existing != null) return existing;

    return createAuthor(AuthorsCompanion.insert(
      accountName: accountName,
      description: Value('Local user'),
    ));
  }
}

final localAuthorRepositoryProvider = Provider<IAuthorRepository>((ref) {
  return LocalAuthorRepository(ref.watch(hmmDatabaseProvider));
});
