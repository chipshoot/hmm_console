import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../data/cheatsheet_templates.dart';
import '../../domain/entities/cheatsheet_card.dart';
import 'card_surface.dart';
import 'cheatsheet_palette.dart';

/// App-bar colours for a card's detail screen. A card with a cover uses the
/// darkened theme with white text, so the bar reads the same whether or not
/// the photo loads (AA-tested in `cheatsheet_palette_test.dart`).
CardColors headerBarColors(CheatsheetCard card, Brightness brightness) =>
    card.cover != null
    ? CheatsheetPalette.forCover(card.look.theme, brightness)
    : CheatsheetPalette.of(card.look.theme, brightness);

/// The detail screen's banner: cover or theme + pattern, icon, title and
/// "group · N rows". A locked sensitive cover offers the shared
/// tap-to-unlock tile here (and only here).
class CardHeader extends StatelessWidget {
  const CardHeader({super.key, required this.card});

  final CheatsheetCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final group = cheatsheetGroupLabel(card.walletGroup, l);
    return SizedBox(
      height: 168,
      child: CardSurface(
        card: card,
        allowUnlock: true,
        builder: (context, ink) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                card.look.icon,
                key: const Key('detail-header-icon'),
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 8),
              Text(
                card.title,
                key: const Key('detail-header-title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.headlineSmall?.copyWith(color: ink.foreground),
              ),
              Text(
                l.cheatsheetTileSubtitle(group, card.rows.length),
                key: const Key('detail-header-subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: ink.subtitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
