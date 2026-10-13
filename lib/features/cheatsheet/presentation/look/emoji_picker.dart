import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/card_style.dart';
import 'emoji_catalog.dart';
import 'look_labels.dart';

/// Opens the picker as a Cupertino popup on iOS and a bottom sheet elsewhere.
/// Returns the chosen emoji, `''` for "No emoji" (offered only when
/// [allowClear]), or null when dismissed.
Future<String?> showEmojiPicker(
  BuildContext context, {
  bool allowClear = false,
}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (_) => CupertinoPopupSurface(
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: EmojiPickerSheet(allowClear: allowClear),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EmojiPickerSheet(allowClear: allowClear),
  );
}

/// Seam so designer widget tests never open a real sheet.
final cheatsheetEmojiPickerProvider =
    Provider<Future<String?> Function(BuildContext, {bool allowClear})>(
      (ref) => showEmojiPicker,
    );

/// The picker's content: curated groups, bilingual search, and free typing
/// of any single emoji.
class EmojiPickerSheet extends StatefulWidget {
  const EmojiPickerSheet({super.key, this.allowClear = false});

  final bool allowClear;

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  String _query = '';
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _choose(String emoji) => Navigator.of(context).pop(emoji);

  Widget _button(EmojiEntry e, bool zh) => Semantics(
    button: true,
    label: zh ? e.zh.first : e.en.first,
    onTap: () => _choose(e.emoji),
    excludeSemantics: true,
    child: InkWell(
      key: Key('emoji-${e.emoji}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => _choose(e.emoji),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(e.emoji, style: const TextStyle(fontSize: 28)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final custom = _custom.text.trim();
    final valid = isSingleEmoji(custom);
    final results = EmojiCatalog.search(_query);

    final List<Widget> grid;
    if (_query.trim().isEmpty) {
      grid = [
        for (final g in EmojiGroup.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              emojiGroupLabel(g, l),
              key: Key('emoji-group-${g.name}'),
              style: theme.textTheme.labelLarge,
            ),
          ),
          Wrap(
            children: [for (final e in EmojiCatalog.inGroup(g)) _button(e, zh)],
          ),
        ],
      ];
    } else if (results.isEmpty) {
      grid = [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l.cheatsheetEmojiNoMatches,
            key: const Key('emoji-no-matches'),
          ),
        ),
      ];
    } else {
      grid = [
        Wrap(children: [for (final e in results) _button(e, zh)]),
      ];
    }

    final search = ios
        ? CupertinoSearchTextField(
            key: const Key('emoji-search'),
            placeholder: l.cheatsheetEmojiSearchHint,
            onChanged: (v) => setState(() => _query = v),
          )
        : TextField(
            key: const Key('emoji-search'),
            decoration: InputDecoration(
              hintText: l.cheatsheetEmojiSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          );

    final customField = ios
        ? CupertinoTextField(
            key: const Key('emoji-custom'),
            controller: _custom,
            placeholder: l.cheatsheetEmojiCustomLabel,
            onChanged: (_) => setState(() {}),
          )
        : TextField(
            key: const Key('emoji-custom'),
            controller: _custom,
            decoration: InputDecoration(
              labelText: l.cheatsheetEmojiCustomLabel,
            ),
            onChanged: (_) => setState(() {}),
          );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.cheatsheetEmojiPickerTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (widget.allowClear)
                  TextButton(
                    key: const Key('emoji-clear'),
                    onPressed: () => _choose(''),
                    child: Text(l.cheatsheetEmojiClear),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            search,
            Expanded(child: ListView(children: grid)),
            Row(
              children: [
                Expanded(child: customField),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('emoji-custom-use'),
                  onPressed: valid ? () => _choose(custom) : null,
                  child: Text(l.cheatsheetEmojiUse),
                ),
              ],
            ),
            if (custom.isNotEmpty && !valid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.cheatsheetEmojiInvalid,
                  key: const Key('emoji-custom-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            SizedBox(height: 12 + MediaQuery.viewInsetsOf(context).bottom),
          ],
        ),
      ),
    );
  }
}
