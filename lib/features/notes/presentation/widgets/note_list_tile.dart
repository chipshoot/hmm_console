import 'package:flutter/material.dart';

import '../../../../core/data/local/database.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../data/models/hmm_note.dart';

class NoteListTile extends StatelessWidget {
  const NoteListTile({super.key, required this.note, this.catalog, this.onTap});

  final HmmNote note;
  final NoteCatalog? catalog;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = CatalogPalette.styleFor(catalog?.name);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(radius: 6, backgroundColor: style.color),
      title: Text(note.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${style.displayName} · ${note.createDate.toLocal().toString().split(' ').first}',
      ),
    );
  }
}
