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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            card.look.icon,
                            key: const Key('card-tile-icon'),
                            style: const TextStyle(fontSize: 28),
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
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        card.title,
                        key: const Key('card-tile-title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          color: ink.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.cheatsheetTileSubtitle(group, count),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: ink.subtitle),
                      ),
                    ],
                  ),
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
