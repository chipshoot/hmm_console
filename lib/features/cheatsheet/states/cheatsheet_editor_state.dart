import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';

import '../../../core/util/uuid.dart';
import '../data/cheatsheet_templates.dart';
import '../domain/entities/cheatsheet_card.dart';
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';
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
  void load(CheatsheetCard existing) => state = existing;

  void setTitle(String title) => state = state.copyWith(title: title);

  void setWalletGroup(String group) =>
      state = state.copyWith(walletGroup: group);

  void setTags(List<String> tags) => state = state.copyWith(tags: tags);

  void addRow(String label) => state = state.copyWith(
        rows: [...state.rows, CheatsheetRow(label: label, source: null)],
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

  Future<void> commit() =>
      ref.read(cheatsheetsStateProvider.notifier).save(state);

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
