import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  CheatsheetCard build() => _blank;

  /// Drop the working copy.
  ///
  /// This provider outlives the designer screen, so a card left here after a
  /// save would be inherited by the *next* "new card" — which, because the
  /// designer treats a non-empty id as "already started", would skip the
  /// template chooser and then save under the previous card's id, silently
  /// overwriting it. The designer calls this on entering create mode.
  void reset() => state = _blank;

  /// Begin a new card. The id is minted here, once.
  void startFromTemplate(String templateId) {
    final template = CheatsheetTemplates.all.firstWhere(
      (t) => t.id == templateId,
      orElse: () => CheatsheetTemplates.all.firstWhere((t) => t.id == 'blank'),
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
