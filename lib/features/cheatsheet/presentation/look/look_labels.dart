import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/card_style.dart';
import 'emoji_catalog.dart';

/// Display names. The stored values stay the enum names; only these are
/// translated, so a language change never re-groups or re-styles a card.
String cheatsheetThemeLabel(CardThemeId theme, AppLocalizations l) =>
    switch (theme) {
      CardThemeId.blue => l.cheatsheetThemeBlue,
      CardThemeId.green => l.cheatsheetThemeGreen,
      CardThemeId.orange => l.cheatsheetThemeOrange,
      CardThemeId.red => l.cheatsheetThemeRed,
      CardThemeId.purple => l.cheatsheetThemePurple,
      CardThemeId.teal => l.cheatsheetThemeTeal,
      CardThemeId.pink => l.cheatsheetThemePink,
      CardThemeId.amber => l.cheatsheetThemeAmber,
      CardThemeId.slate => l.cheatsheetThemeSlate,
      CardThemeId.indigo => l.cheatsheetThemeIndigo,
      CardThemeId.brown => l.cheatsheetThemeBrown,
      CardThemeId.black => l.cheatsheetThemeBlack,
    };

String cheatsheetPatternLabel(CardPattern pattern, AppLocalizations l) =>
    switch (pattern) {
      CardPattern.none => l.cheatsheetPatternNone,
      CardPattern.dots => l.cheatsheetPatternDots,
      CardPattern.stripes => l.cheatsheetPatternStripes,
      CardPattern.grid => l.cheatsheetPatternGrid,
      CardPattern.waves => l.cheatsheetPatternWaves,
    };

String cheatsheetLayoutLabel(CardLayout layout, AppLocalizations l) =>
    switch (layout) {
      CardLayout.facts => l.cheatsheetLayoutFacts,
      CardLayout.keyPoints => l.cheatsheetLayoutKeyPoints,
    };

String emojiGroupLabel(EmojiGroup group, AppLocalizations l) => switch (group) {
  EmojiGroup.vehicle => l.cheatsheetEmojiGroupVehicle,
  EmojiGroup.health => l.cheatsheetEmojiGroupHealth,
  EmojiGroup.home => l.cheatsheetEmojiGroupHome,
  EmojiGroup.books => l.cheatsheetEmojiGroupBooks,
  EmojiGroup.work => l.cheatsheetEmojiGroupWork,
  EmojiGroup.travel => l.cheatsheetEmojiGroupTravel,
  EmojiGroup.money => l.cheatsheetEmojiGroupMoney,
  EmojiGroup.misc => l.cheatsheetEmojiGroupMisc,
};
