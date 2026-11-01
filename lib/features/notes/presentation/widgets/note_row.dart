import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/local/local_tag_repository.dart';
import '../../../../core/data/vault/sensitive_path.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../query/note_results.dart';
import '../../rendering/note_display.dart';
import '../catalog_labels.dart';
import 'note_flag_sheet.dart' show noteFlagColorLabel;
import 'note_preview_text.dart';

/// One row of the Notes list: a domain-coloured bar, the title (with search
/// matches marked, a pin and a flag), a preview sized by [density], and a meta
/// line. Rich rows add a thumbnail of the note's primary image.
class NoteRow extends ConsumerWidget {
  const NoteRow({
    super.key,
    required this.hit,
    required this.density,
    required this.domainKey,
    required this.catalogName,
    required this.parentTitle,
    required this.tags,
    required this.date,
    this.highlightWords = const [],
    required this.now,
    this.onTap,
  });

  final NoteHit hit;
  final NoteRowDensity density;
  final String? domainKey;
  final String? catalogName;
  final String? parentTitle;
  final List<NoteTagLabel> tags;

  /// The date shown at the trailing edge and read out: the one the row is
  /// grouped by (see `groupingDateOf`), so it never contradicts its header.
  final DateTime date;
  final List<String> highlightWords;
  final DateTime now;
  final VoidCallback? onTap;

  static const _thumb = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final note = hit.note;
    final barColor = domainKey != null
        ? CatalogPalette.domainStyle(domainKey!).color
        : CatalogPalette.styleFor(catalogName).color;

    final when = date.toLocal();
    final DateFormat format;
    if (when.year == now.year &&
        when.month == now.month &&
        when.day == now.day) {
      format = DateFormat.jm(locale);
    } else if (when.year == now.year) {
      format = DateFormat.MMMd(locale);
    } else {
      format = DateFormat.yMd(locale);
    }
    final timeText = format.format(when);

    final registry = ref.watch(noteDisplayRegistryProvider);
    final isEntity = registry.hasEntry(catalogName);
    final plain = isEntity
        ? registry.noteDisplay(note, catalogName, l).preview
        : null;
    final markdown = note.content ?? '';
    final hasPreview = isEntity ? plain!.isNotEmpty : markdown.isNotEmpty;

    final flag = hit.state.flag;
    final pinned = hit.state.isPinned;
    final semantics = [
      l.notesRowSemantics(hit.title, timeText),
      if (flag != null) l.notesRowSemanticsFlagged(noteFlagColorLabel(flag, l)),
      if (pinned) l.notesRowSemanticsPinned,
      if (hasPreview) isEntity ? plain! : previewPlain(previewRuns(markdown)),
    ].join(', ');

    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final matchStyle = TextStyle(
      backgroundColor: c.accent.withValues(alpha: 0.25),
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final thumbnail = density == NoteRowDensity.rich
        ? _thumbnail(context, ref)
        : null;

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: barColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              _titleSpan(
                                hit.title,
                                hit.titleMatches,
                                matchStyle,
                              ),
                              style: titleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pinned) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.push_pin, size: 14, color: c.accent),
                          ],
                          const SizedBox(width: 6),
                          Text(timeText, style: muted),
                          if (flag != null) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.flag, size: 14, color: flag.color),
                          ],
                        ],
                      ),
                      if (density != NoteRowDensity.compact && hasPreview)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: DefaultTextStyle.merge(
                            style: muted,
                            child: NotePreviewText(
                              markdown: isEntity ? '' : markdown,
                              plainText: plain,
                              maxLines: density == NoteRowDensity.rich ? 4 : 2,
                              highlightWords: highlightWords,
                            ),
                          ),
                        ),
                      _meta(context, l, muted),
                    ],
                  ),
                ),
              ),
              if (thumbnail != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12, top: 8),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: thumbnail,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Title text with [matches] marked. Ranges can come from a cached folded
  /// title, so any part outside [title] is clamped away rather than trusted.
  static TextSpan _titleSpan(
    String title,
    List<TextRange> matches,
    TextStyle matchStyle,
  ) {
    final ranges = <TextRange>[];
    for (final m in matches) {
      final s = m.start < 0 ? 0 : m.start;
      final e = m.end > title.length ? title.length : m.end;
      if (s < e) ranges.add(TextRange(start: s, end: e));
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in ranges) {
      final start = r.start < cursor ? cursor : r.start;
      if (start >= r.end) continue;
      if (start > cursor) {
        spans.add(TextSpan(text: title.substring(cursor, start)));
      }
      spans.add(
        TextSpan(text: title.substring(start, r.end), style: matchStyle),
      );
      cursor = r.end;
    }
    if (cursor < title.length) {
      spans.add(TextSpan(text: title.substring(cursor)));
    }
    return TextSpan(children: spans);
  }

  Widget _meta(BuildContext context, AppLocalizations l, TextStyle? muted) {
    final note = hit.note;
    final iconColor = muted?.color;
    WidgetSpan icon(IconData d) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(d, size: 12, color: iconColor),
    );

    final parts = <List<InlineSpan>>[];
    if (domainKey != null) {
      parts.add([TextSpan(text: domainLabel(domainKey!, l))]);
    }
    if (parentTitle != null && parentTitle!.isNotEmpty) {
      parts.add([TextSpan(text: parentTitle)]);
    }
    if (tags.isNotEmpty) {
      final shown = tags.take(2).map((t) => t.name).join(', ');
      final extra = tags.length - 2;
      parts.add([
        icon(Icons.sell_outlined),
        TextSpan(
          text: extra > 0
              ? ' $shown ${l.notesRowMoreTags('$extra')}'
              : ' $shown',
        ),
      ]);
    }
    final a = note.effectiveAttachments;
    final count =
        (a.primaryImage == null ? 0 : 1) + a.images.length + a.files.length;
    if (count > 0) {
      parts.add([icon(Icons.attach_file), TextSpan(text: ' $count')]);
    }
    if (note.location != null) {
      final label = note.locationLabel;
      parts.add([
        icon(Icons.place_outlined),
        if (label != null && label.isNotEmpty) TextSpan(text: ' $label'),
      ]);
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' · '));
      spans.addAll(parts[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(children: spans),
        style: muted,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget? _thumbnail(BuildContext context, WidgetRef ref) {
    final a = hit.note.effectiveAttachments;
    final AttachmentRef? image =
        a.primaryImage ?? (a.images.isEmpty ? null : a.images.first);
    if (image == null) return null;
    final radius = BorderRadius.circular(8);
    final scheme = Theme.of(context).colorScheme;
    Widget box(Widget? child) => Container(
      width: _thumb,
      height: _thumb,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: child,
    );

    final sensitive =
        image is VaultRef &&
        (image.sensitive || isSensitiveVaultPath(image.path));
    if (sensitive) {
      return box(Icon(Icons.lock_outline, color: scheme.onSurfaceVariant));
    }
    final resolver = ref.watch(attachmentResolverProvider);
    return resolver.when(
      loading: () => box(null),
      error: (_, _) => box(null),
      data: (r) => ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: _thumb,
          height: _thumb,
          child: AttachmentImage(
            ref: image,
            resolver: r,
            alignment: Alignment.topCenter,
            loadingPlaceholder: box(null),
            errorPlaceholder: box(null),
          ),
        ),
      ),
    );
  }
}
