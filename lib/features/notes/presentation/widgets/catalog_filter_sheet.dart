import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../../../core/notes/catalog_palette.dart';
import 'domain_groups.dart';

/// Filter sheet that organizes catalogs into collapsible domain sections
/// (e.g. Automobile ▸ Gas Log, Gas Station, …) instead of one long flat list.
///
/// Tapping a domain's "All …" row filters to every catalog in that domain;
/// tapping an individual catalog filters to just that one. Both record the
/// domain via [onRecordDomain] so the inline quick chips adapt to usage.
class CatalogFilterSheet extends StatelessWidget {
  const CatalogFilterSheet({
    super.key,
    required this.groups,
    required this.counts,
    required this.selected, // null = All
    required this.onApply,
    required this.onRecordDomain,
  });

  final List<DomainGroup> groups;
  final Map<int, int> counts;
  final Set<int>? selected;
  final ValueChanged<Set<int>?> onApply;
  final ValueChanged<String> onRecordDomain;

  void _pick(BuildContext context, String domainKey, Set<int>? ids) {
    onRecordDomain(domainKey);
    onApply(ids);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All notes'),
            trailing: selected == null ? const Icon(Icons.check) : null,
            onTap: () {
              onApply(null);
              Navigator.of(context).pop();
            },
          ),
          const Divider(height: 1),
          for (final g in groups)
            ExpansionTile(
              leading: CircleAvatar(radius: 6, backgroundColor: g.style.color),
              title: Text(g.style.displayName),
              subtitle:
                  Text('${g.noteCount} note${g.noteCount == 1 ? '' : 's'}'),
              childrenPadding: const EdgeInsets.only(left: 16),
              children: [
                ListTile(
                  title: Text('All ${g.style.displayName}'),
                  trailing: setEquals(selected, g.catalogIds)
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => _pick(context, g.key, g.catalogIds),
                ),
                for (final c in g.catalogs)
                  ListTile(
                    leading: CircleAvatar(
                        radius: 5,
                        backgroundColor: CatalogPalette.styleFor(c.name).color),
                    title: Text(CatalogPalette.styleFor(c.name).displayName),
                    trailing: Text('${counts[c.id] ?? 0}'),
                    selected: selected != null &&
                        selected!.length == 1 &&
                        selected!.contains(c.id),
                    onTap: () => _pick(context, g.key, {c.id}),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
