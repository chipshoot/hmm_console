import '../../../../core/data/local/database.dart';
import '../../../../core/notes/catalog_palette.dart';

/// One domain's catalogs plus aggregate note count, for the chip row and the
/// grouped filter sheet.
class DomainGroup {
  DomainGroup(this.key, this.catalogs, this.noteCount);

  final String key;
  final List<NoteCatalog> catalogs;
  final int noteCount;

  Set<int> get catalogIds => catalogs.map((c) => c.id).toSet();
  CatalogStyle get style => CatalogPalette.domainStyle(key);
}

/// Group [catalogs] by domain, ordered by [usage] (desc), then aggregate note
/// count (desc), then domain name. [counts] maps catalogId -> note count.
List<DomainGroup> groupByDomain(
  Iterable<NoteCatalog> catalogs,
  Map<int, int> counts,
  Map<String, int> usage,
) {
  final byDomain = <String, List<NoteCatalog>>{};
  for (final c in catalogs) {
    byDomain.putIfAbsent(CatalogPalette.domainKeyFor(c.name), () => []).add(c);
  }
  final groups = byDomain.entries.map((e) {
    final noteCount = e.value.fold<int>(0, (sum, c) => sum + (counts[c.id] ?? 0));
    return DomainGroup(e.key, e.value, noteCount);
  }).toList();
  groups.sort((a, b) {
    final byUsage = (usage[b.key] ?? 0).compareTo(usage[a.key] ?? 0);
    if (byUsage != 0) return byUsage;
    final byNotes = b.noteCount.compareTo(a.noteCount);
    if (byNotes != 0) return byNotes;
    return a.style.displayName.compareTo(b.style.displayName);
  });
  return groups;
}
