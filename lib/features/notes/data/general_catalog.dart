import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local/database.dart';
import '../../../core/data/repository_providers.dart';
import '../../../core/notes/catalog_palette.dart';

const String _generalSchema = '{"type":"markdown"}';
// NoteContentFormatType: PlainText=0, Xml=1, Json=2, Markdown=3.
const int _formatMarkdown = 3;

Future<NoteCatalog> ensureGeneralCatalog(Ref ref) async {
  final repo = ref.read(noteCatalogRepositoryProvider);
  final existing = await repo.getCatalogByName(kGeneralCatalogName);
  if (existing != null) return existing;
  return repo.createCatalog(NoteCatalogsCompanion.insert(
    name: kGeneralCatalogName,
    schema: _generalSchema,
    formatType: const Value(_formatMarkdown),
  ));
}

final generalCatalogProvider =
    FutureProvider<NoteCatalog>((ref) => ensureGeneralCatalog(ref));
