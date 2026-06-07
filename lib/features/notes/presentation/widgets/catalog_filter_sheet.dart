import 'package:flutter/material.dart';

import '../../../../core/data/local/database.dart';
import '../../../../core/notes/catalog_palette.dart';

class CatalogFilterSheet extends StatelessWidget {
  const CatalogFilterSheet({
    super.key,
    required this.catalogs,
    required this.counts,
    required this.selected, // null = All
    required this.onApply,
  });

  final List<NoteCatalog> catalogs;
  final Map<int, int> counts;
  final Set<int>? selected;
  final ValueChanged<Set<int>?> onApply;

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
          for (final c in catalogs)
            ListTile(
              leading: CircleAvatar(
                  radius: 6,
                  backgroundColor: CatalogPalette.styleFor(c.name).color),
              title: Text(CatalogPalette.styleFor(c.name).displayName),
              trailing: Text('${counts[c.id] ?? 0}'),
              selected: selected?.contains(c.id) ?? false,
              onTap: () {
                onApply({c.id});
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
