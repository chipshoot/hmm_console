import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';

import '../../../core/util/uuid.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../data/cheatsheet_templates.dart';
import '../domain/entities/cheatsheet_card.dart';
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';
import '../domain/entities/card_style.dart';
import 'cheatsheet_cover_draft.dart';
import 'cheatsheets_state.dart';

/// Card ids come from here so tests can pin them. Production is the real v4
/// generator; callers never pass an id in.
final cheatsheetIdGenProvider = Provider<String Function()>(
  (ref) => generateUuid,
);

/// The designer's working copy.
///
/// Identity is the invariant worth guarding: [startFromTemplate] mints exactly
/// one id, [load] adopts an existing card's id untouched, and nothing else
/// writes `id`. That is what keeps editing an update instead of a second card.
class CheatsheetEditor extends Notifier<CheatsheetCard> {
  static const _blank = CheatsheetCard(
    id: '',
    title: '',
    walletGroup: 'Ungrouped',
    tags: [],
    templateId: 'blank',
    rows: [],
  );

  /// The working copy starts blank.
  ///
  /// This provider outlives the designer screen, so a leftover card must
  /// never decide what the next visit shows — the designer keeps a
  /// visit-local `_started` flag for that, and [load]/[startFromTemplate]
  /// overwrite this state on every real entry.
  @override
  CheatsheetCard build() => _blank;

  /// Begin a new card. The id is minted here, once.
  ///
  /// [l] is passed in rather than resolved from a context: this is a Notifier
  /// with no element tree, and the template's row labels are localized because
  /// they seed the card's editable content (see `cheatsheet_templates.dart`).
  void startFromTemplate(String templateId, AppLocalizations l) {
    ref.read(cheatsheetCoverDraftProvider.notifier).clear();
    final templates = CheatsheetTemplates.all(l);
    final template = templates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => templates.firstWhere((t) => t.id == 'blank'),
    );
    state = CheatsheetTemplates.instantiate(
      template,
      ref.read(cheatsheetIdGenProvider)(),
    );
  }

  /// Begin editing an existing card, preserving its id.
  void load(CheatsheetCard existing) {
    // A cover picked on an earlier, abandoned visit must not ride along.
    ref.read(cheatsheetCoverDraftProvider.notifier).clear();
    state = existing;
  }

  void setTitle(String title) => state = state.copyWith(title: title);

  void setWalletGroup(String group) =>
      state = state.copyWith(walletGroup: group);

  void setTags(List<String> tags) => state = state.copyWith(tags: tags);

  void addRow(String label) => state = state.copyWith(
    rows: [
      ...state.rows,
      CheatsheetRow(label: label, source: null),
    ],
  );

  void removeRow(int index) {
    if (!_inRange(index)) return;
    state = state.copyWith(rows: [...state.rows]..removeAt(index));
  }

  void bindRow(int index, CheatsheetSource source) =>
      _updateRow(index, (r) => r.copyWith(source: source));

  void unbindRow(int index) =>
      _updateRow(index, (r) => r.copyWith(clearSource: true));

  void setValueAction(int index, ValueAction action) =>
      _updateRow(index, (r) => r.copyWith(valueAction: action));

  void setOpenSource(int index, bool open) =>
      _updateRow(index, (r) => r.copyWith(openSource: open));

  void setTheme(CardThemeId theme) => state = state.copyWith(
    style: state.style.withTheme(theme, templateId: state.templateId),
  );

  void setPattern(CardPattern pattern) =>
      state = state.copyWith(style: state.style.withPattern(pattern));

  /// Null or empty returns the card to its template icon.
  void setIcon(String? icon) => state = state.copyWith(
    style: state.style.withIcon(icon, templateId: state.templateId),
  );

  /// Row emoji are untouched: Facts hides them, it never deletes them.
  void setLayout(CardLayout layout) => state = state.copyWith(
    style: state.style.withLayout(layout, templateId: state.templateId),
  );

  /// Null or empty clears the row's emoji.
  void setRowEmoji(int index, String? emoji) => _updateRow(
    index,
    (r) => emoji == null || emoji.isEmpty
        ? r.copyWith(clearEmoji: true)
        : r.copyWith(emoji: emoji),
  );

  /// Stages [pick] as the new cover; a stored cover is released on save.
  void pickCover(PickedImageBytes pick) {
    final draft = ref.read(cheatsheetCoverDraftProvider.notifier);
    final old = state.cover;
    if (old != null) draft.release(old);
    state = state.withCover(null);
    draft.stage(pick);
  }

  void removeCover() {
    final draft = ref.read(cheatsheetCoverDraftProvider.notifier);
    draft.dropPending();
    final old = state.cover;
    if (old != null) draft.release(old);
    state = state.withCover(null);
  }

  /// Back to the template look: no style (including a preserved raw one), no
  /// row emoji (including preserved raw ones), no cover.
  void resetLook() {
    removeCover();
    state = state.copyWith(
      style: CardStyle.empty,
      extraFields: {
        for (final e in state.extraFields.entries)
          if (e.key != 'style') e.key: e.value,
      },
      rows: [
        for (final r in state.rows)
          r.copyWith(
            clearEmoji: true,
            extraFields: {
              for (final e in r.extraFields.entries)
                if (e.key != 'emoji') e.key: e.value,
            },
          ),
      ],
    );
  }

  Future<void> commit() {
    final draft = ref.read(cheatsheetCoverDraftProvider);
    return ref
        .read(cheatsheetsStateProvider.notifier)
        .save(state, newCover: draft.pending, released: draft.released);
  }

  bool _inRange(int index) => index >= 0 && index < state.rows.length;

  /// A stale index from a rebuilding form is a no-op, not a crash.
  void _updateRow(int index, CheatsheetRow Function(CheatsheetRow) f) {
    if (!_inRange(index)) return;
    final rows = [...state.rows];
    rows[index] = f(rows[index]);
    state = state.copyWith(rows: rows);
  }
}

final cheatsheetEditorProvider =
    NotifierProvider<CheatsheetEditor, CheatsheetCard>(CheatsheetEditor.new);
