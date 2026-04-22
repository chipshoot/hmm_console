import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

abstract interface class INoteCatalogRepository {
  Future<List<NoteCatalog>> getCatalogs();

  Future<NoteCatalog?> getCatalogById(int id);

  Future<NoteCatalog?> getCatalogByName(String name);

  Future<NoteCatalog> createCatalog(NoteCatalogsCompanion catalog);

  Future<NoteCatalog> updateCatalog(int id, NoteCatalogsCompanion catalog);

  Future<NoteCatalog> getOrCreateCatalog(String name, String schema);
}

class LocalNoteCatalogRepository implements INoteCatalogRepository {
  LocalNoteCatalogRepository(this._db);

  final HmmDatabase _db;

  @override
  Future<List<NoteCatalog>> getCatalogs() async {
    return await _db.select(_db.noteCatalogs).get();
  }

  @override
  Future<NoteCatalog?> getCatalogById(int id) async {
    return await (_db.select(_db.noteCatalogs)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<NoteCatalog?> getCatalogByName(String name) async {
    return await (_db.select(_db.noteCatalogs)
          ..where((c) => c.name.lower().equals(name.toLowerCase().trim())))
        .getSingleOrNull();
  }

  @override
  Future<NoteCatalog> createCatalog(NoteCatalogsCompanion catalog) async {
    final id = await _db.into(_db.noteCatalogs).insert(catalog);
    return (await getCatalogById(id))!;
  }

  @override
  Future<NoteCatalog> updateCatalog(int id, NoteCatalogsCompanion catalog) async {
    await (_db.update(_db.noteCatalogs)..where((c) => c.id.equals(id)))
        .write(catalog);
    return (await getCatalogById(id))!;
  }

  @override
  Future<NoteCatalog> getOrCreateCatalog(String name, String schema) async {
    final existing = await getCatalogByName(name);
    if (existing != null) return existing;

    return createCatalog(NoteCatalogsCompanion.insert(
      name: name,
      schema: schema,
    ));
  }
}

final localNoteCatalogRepositoryProvider = Provider<INoteCatalogRepository>((ref) {
  return LocalNoteCatalogRepository(ref.watch(hmmDatabaseProvider));
});
