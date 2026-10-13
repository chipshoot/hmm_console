import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/scanner/document_scanner.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/card_style.dart';
import '../../states/cheatsheet_cover_draft.dart';
import '../../states/cheatsheet_covers_supported.dart';
import '../../states/cheatsheet_editor_state.dart';
import '../look/card_surface.dart';
import '../look/card_tile.dart';
import '../look/cheatsheet_palette.dart';
import '../look/cover_action_sheet.dart';
import '../look/emoji_picker.dart';
import '../look/look_labels.dart';

/// The designer's "Look" section, with the real wallet tile scaled down as a
/// live preview in its header. Expanded when creating a card (choosing the
/// look is part of making it); collapsed when editing one, where the preview
/// alone shows the current look and the rows stay in the first viewport.
class LookSection extends ConsumerWidget {
  const LookSection({super.key, required this.initiallyExpanded});

  /// The designer passes `cardId == null`: true on create, false on edit.
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final card = ref.watch(cheatsheetEditorProvider);
    final draft = ref.watch(cheatsheetCoverDraftProvider);
    return ExpansionTile(
      key: const Key('designer-look'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: SizedBox(
        key: const Key('look-preview'),
        width: 75,
        height: 56,
        child: FittedBox(
          child: SizedBox(
            width: 200,
            height: 150,
            child: CardTile(
              card: card,
              pendingCoverBytes: draft.pending?.bytes,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          const Icon(Icons.palette_outlined, size: 20),
          const SizedBox(width: 8),
          Text(l.cheatsheetLookTitle),
        ],
      ),
      // Built only when expanded (maintainState is false), so a collapsed
      // section reads no providers beyond the editor and the cover draft.
      children: const [_LookBody()],
    );
  }
}

class _LookBody extends ConsumerWidget {
  const _LookBody();

  static IconData _layoutIcon(CardLayout layout) => switch (layout) {
    CardLayout.facts => Icons.list_alt,
    CardLayout.keyPoints => Icons.format_list_numbered,
  };

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  Future<void> _chooseIcon(BuildContext context, WidgetRef ref) async {
    final editor = ref.read(cheatsheetEditorProvider.notifier);
    final pick = ref.read(cheatsheetEmojiPickerProvider);
    final chosen = await pick(context, allowClear: true);
    if (chosen == null) return;
    editor.setIcon(chosen.isEmpty ? null : chosen);
  }

  /// Reuses the app's pickers: camera / library through [ImageByteSource]
  /// and the OS document scanner. Bytes are downsized when the save writes
  /// them to the vault (`persistToVault`), as for every other photo.
  Future<void> _chooseCover(
    BuildContext context,
    WidgetRef ref, {
    required bool hasCover,
  }) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final editor = ref.read(cheatsheetEditorProvider.notifier);
    final scanner = ref.read(documentScannerProvider);
    final source = ref.read(imageByteSourceProvider);
    final chooseAction = ref.read(cheatsheetCoverActionProvider);
    try {
      final canScan = await scanner.isAvailable();
      if (!context.mounted) return;
      final action = await chooseAction(
        context,
        hasCover: hasCover,
        canScan: canScan,
      );
      switch (action) {
        case null:
          return;
        case CoverAction.remove:
          editor.removeCover();
        case CoverAction.camera:
          {
            final pick = await source.pick(AttachmentPickSource.camera);
            if (pick != null) editor.pickCover(pick);
          }
        case CoverAction.library:
          {
            final pick = await source.pick(AttachmentPickSource.gallery);
            if (pick != null) editor.pickCover(pick);
          }
        case CoverAction.scan:
          {
            final pages = await scanner.scan();
            // A cover is one image: a multi-page scan uses page 1 only.
            if (pages.isNotEmpty) editor.pickCover(pages.first);
          }
      }
    } on Exception catch (e) {
      // Type only: platform errors can quote file paths.
      debugPrint(
        'LookSection: choosing a cover failed (${e.runtimeType}); '
        'nothing changed.',
      );
      messenger.showSnackBar(SnackBar(content: Text(l.cheatsheetCoverFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final card = ref.watch(cheatsheetEditorProvider);
    final draft = ref.watch(cheatsheetCoverDraftProvider);
    final coversSupported = ref.watch(cheatsheetCoversSupportedProvider);
    final editor = ref.read(cheatsheetEditorProvider.notifier);
    final look = card.look;
    final brightness = Theme.of(context).brightness;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final pending = draft.pending;
    final hasCover = pending != null || card.cover != null;

    final Widget layoutControl = ios
        ? CupertinoSlidingSegmentedControl<CardLayout>(
            key: const Key('look-layout'),
            groupValue: look.layout,
            children: {
              for (final x in CardLayout.values)
                x: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_layoutIcon(x), size: 18),
                      const SizedBox(width: 6),
                      Text(cheatsheetLayoutLabel(x, l)),
                    ],
                  ),
                ),
            },
            onValueChanged: (v) {
              if (v != null) editor.setLayout(v);
            },
          )
        : SegmentedButton<CardLayout>(
            key: const Key('look-layout'),
            segments: [
              for (final x in CardLayout.values)
                ButtonSegment(
                  value: x,
                  icon: Icon(_layoutIcon(x)),
                  label: Text(cheatsheetLayoutLabel(x, l)),
                ),
            ],
            selected: {look.layout},
            onSelectionChanged: (s) => editor.setLayout(s.first),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, l.cheatsheetLookTheme),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in CardThemeId.values)
              _ThemeSwatch(
                theme: t,
                colors: CheatsheetPalette.of(t, brightness),
                label: cheatsheetThemeLabel(t, l),
                selected: look.theme == t,
                onTap: () => editor.setTheme(t),
              ),
          ],
        ),
        _label(context, l.cheatsheetLookPattern),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in CardPattern.values)
              _PatternSwatch(
                pattern: p,
                colors: CheatsheetPalette.of(look.theme, brightness),
                label: cheatsheetPatternLabel(p, l),
                selected: look.pattern == p,
                onTap: () => editor.setPattern(p),
              ),
          ],
        ),
        _label(context, l.cheatsheetLookIcon),
        Row(
          children: [
            Text(
              look.icon,
              key: const Key('look-icon'),
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              key: const Key('look-icon-choose'),
              onPressed: () => _chooseIcon(context, ref),
              icon: const Icon(Icons.emoji_emotions_outlined),
              label: Text(l.cheatsheetIconChoose),
            ),
          ],
        ),
        if (coversSupported) ...[
          _label(context, l.cheatsheetLookCover),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasCover)
                SizedBox(
                  key: const Key('look-cover-thumb'),
                  width: 56,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: pending != null
                        ? Image.memory(pending.bytes, fit: BoxFit.cover)
                        : CardSurface(
                            card: card,
                            builder: (_, _) => const SizedBox.shrink(),
                          ),
                  ),
                ),
              TextButton.icon(
                key: const Key('look-cover-add'),
                onPressed: () => _chooseCover(context, ref, hasCover: hasCover),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  hasCover ? l.cheatsheetCoverChange : l.cheatsheetCoverAdd,
                ),
              ),
              if (hasCover)
                TextButton(
                  key: const Key('look-cover-remove'),
                  onPressed: editor.removeCover,
                  child: Text(l.cheatsheetCoverRemove),
                ),
            ],
          ),
        ],
        _label(context, l.cheatsheetLookLayout),
        layoutControl,
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('look-reset'),
          onPressed: editor.resetLook,
          icon: const Icon(Icons.format_color_reset_outlined),
          label: Text(l.cheatsheetLookReset),
        ),
      ],
    );
  }
}

/// One colour choice. Named for screen readers; a check mark (not only the
/// colour) shows the selection.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CardThemeId theme;
  final CardColors colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      key: Key('look-theme-${theme.name}'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                key: Key('look-theme-${theme.name}-selected'),
                size: 20,
                color: colors.foreground,
              )
            : null,
      ),
    ),
  );
}

class _PatternSwatch extends StatelessWidget {
  const _PatternSwatch({
    required this.pattern,
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CardPattern pattern;
  final CardColors colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      key: Key('look-pattern-${pattern.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 36,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        // Stronger ink than on a card, so the swatch reads at this size.
        child: CustomPaint(
          painter: CardPatternPainter(
            pattern: pattern,
            ink: colors.foreground.withValues(alpha: 0.35),
          ),
        ),
      ),
    ),
  );
}
