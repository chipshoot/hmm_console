import 'package:flutter/material.dart';

import '../../../../core/data/local/database.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../../../core/widgets/app_list_row.dart';
import '../../data/models/hmm_note.dart';
import '../util/note_preview.dart';

/// A single note row. Fills [AppListRow]: catalog dot leading, subject title,
/// first content line as the bold primary line, and `catalog · date` secondary.
class NoteListTile extends StatelessWidget {
  const NoteListTile({super.key, required this.note, this.catalog, this.onTap});

  final HmmNote note;
  final NoteCatalog? catalog;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = CatalogPalette.styleFor(catalog?.name);
    final preview = notePreview(note.content);
    final date = note.effectiveNoteDate.toLocal().toString().split(' ').first;

    return AppListRow(
      onTap: onTap,
      leading: Container(
        width: 11,
        height: 11,
        margin: const EdgeInsetsDirectional.only(top: 4),
        decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      ),
      title: Text(note.subject),
      primary: preview.isEmpty ? null : Text(preview),
      secondary: Text('${style.displayName} · $date'),
    );
  }
}
