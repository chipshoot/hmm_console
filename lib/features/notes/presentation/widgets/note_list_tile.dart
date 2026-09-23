import 'package:flutter/material.dart';

import '../catalog_labels.dart';

import '../../../../l10n/gen/app_localizations.dart';

import '../../../../core/data/local/database.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../../../core/widgets/app_list_row.dart';
import '../../data/models/hmm_note.dart';
import '../util/note_preview.dart';

/// A single note row. Fills [AppListRow]: catalog dot leading, subject title,
/// first content line as the bold primary line, and `catalog · date` secondary.
class NoteListTile extends StatelessWidget {
  const NoteListTile({
    super.key,
    required this.note,
    this.catalog,
    this.titleContext,
    this.contextLabel,
    this.contextColor,
    this.onTap,
  });

  final HmmNote note;
  final NoteCatalog? catalog;

  /// What the note hangs off — a car, a policy — shown after the subject.
  /// Composed here and never stored: writing it into the subject would
  /// duplicate on the next render and reach sync and the editor.
  final String? titleContext;

  /// Replaces the catalog label on the secondary line with the domain the
  /// note actually filters under.
  final String? contextLabel;

  /// Replaces the catalog dot's colour with that domain's colour.
  final Color? contextColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = CatalogPalette.styleFor(catalog?.name);
    final preview = notePreview(note.content);
    final date = note.effectiveNoteDate.toLocal().toString().split(' ').first;

    return AppListRow(
      onTap: onTap,
      leading: Container(
        width: 11,
        height: 11,
        margin: const EdgeInsetsDirectional.only(top: 4),
        decoration: BoxDecoration(
          color: contextColor ?? style.color,
          shape: BoxShape.circle,
        ),
      ),
      title: titleContext == null
          ? Text(note.subject)
          : Row(
              children: [
                Flexible(
                  child: Text(note.subject, overflow: TextOverflow.ellipsis),
                ),
                Flexible(
                  child: Text(
                    ' ($titleContext)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
      primary: preview.isEmpty ? null : Text(preview),
      secondary: Text(
        '${contextLabel ?? catalogLabel(catalog?.name, l)} · $date',
      ),
    );
  }
}
