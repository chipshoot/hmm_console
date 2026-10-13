import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../data/cheatsheet_templates.dart';
import '../../domain/entities/cheatsheet_card.dart';
import 'card_surface.dart';

/// A wallet tile: the card's look as background, its icon, a two-line title
/// and "group · N rows". Read by screen readers as one button whose label
/// never relies on colour.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    this.onTap,
    this.pendingCoverBytes,
  });

  final CheatsheetCard card;
  final VoidCallback? onTap;
  final Uint8List? pendingCoverBytes;

  static const TextStyle _iconStyle = TextStyle(fontSize: 28);
  static const TextStyle _badgeStyle = TextStyle(fontSize: 16);
  static const double _lockIconSize = 18;
  static const double _bandTop = 6;
  static const double _titleGap = 2;

  static TextStyle? _titleStyle(TextTheme text, Color? color) =>
      text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600);

  static TextStyle? _subtitleStyle(TextTheme text, Color? color) =>
      text.bodySmall?.copyWith(color: color);

  /// The height a tile needs for its icon row, a two-line title and the
  /// subtitle at the ambient text scale. The wallet grid never makes a tile
  /// shorter than this, so large accessibility text grows the tile instead
  /// of clipping or overflowing it.
  static double minHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    final text = Theme.of(context).textTheme;
    double measure(TextStyle? style, {int lines = 1}) {
      final painter = TextPainter(
        text: TextSpan(
          text: List.filled(lines, 'Ag').join('\n'),
          style: base.merge(style),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: lines,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final iconRow = [
      measure(_iconStyle),
      measure(_badgeStyle),
      _lockIconSize,
    ].reduce((a, b) => a > b ? a : b);
    // Slack for emoji fonts whose ascent/descent exceed the text font's.
    const slack = 4.0;
    return 12 +
        iconRow +
        _bandTop +
        measure(_titleStyle(text, null), lines: 2) +
        _titleGap +
        measure(_subtitleStyle(text, null)) +
        12 +
        slack;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final group = cheatsheetGroupLabel(card.walletGroup, l);
    final count = card.rows.length;
    final text = Theme.of(context).textTheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CardSurface(
          card: card,
          pendingCoverBytes: pendingCoverBytes,
          // Decode at tile size: a full-resolution photo per tile is wasted
          // memory in a scrolling grid.
          coverCacheWidth: constraints.hasBoundedWidth
              ? (constraints.maxWidth * dpr).ceil()
              : null,
          builder: (context, ink) => Semantics(
            button: onTap != null,
            label: _semanticsLabel(l, group, count, ink),
            onTap: onTap,
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Row(
                        children: [
                          Text(
                            card.look.icon,
                            key: const Key('card-tile-icon'),
                            style: _iconStyle,
                          ),
                          const Spacer(),
                          if (card.protected)
                            Icon(
                              Icons.lock_outline,
                              key: const Key('card-tile-protected'),
                              size: 18,
                              color: ink.foreground,
                            ),
                          if (ink.coverLocked)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                '\u{1F512}',
                                key: Key('card-tile-cover-locked'),
                                style: _badgeStyle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Flexible: at a large text scale the text gives way
                    // (ellipsis) instead of overflowing the tile. The grid
                    // sizes tiles with [CardTile.minHeight] so this is the
                    // last resort, not the layout.
                    Flexible(
                      child: DecoratedBox(
                        key: const Key('card-tile-text-band'),
                        decoration: BoxDecoration(color: ink.textBand),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            _bandTop,
                            12,
                            12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  card.title,
                                  key: const Key('card-tile-title'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _titleStyle(text, ink.foreground),
                                ),
                              ),
                              const SizedBox(height: _titleGap),
                              Text(
                                l.cheatsheetTileSubtitle(group, count),
                                key: const Key('card-tile-subtitle'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _subtitleStyle(text, ink.subtitle),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lock state is spoken, never left to the badge's colour or glyph.
  String _semanticsLabel(
    AppLocalizations l,
    String group,
    int count,
    CardInk ink,
  ) {
    final b = StringBuffer(l.cheatsheetTileSemantics(card.title, group, count));
    if (card.protected) b.write(l.cheatsheetTileProtectedSemantics);
    if (ink.coverLocked) b.write(l.cheatsheetTileCoverLockedSemantics);
    return b.toString();
  }
}
