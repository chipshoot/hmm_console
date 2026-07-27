import 'cheatsheet_row.dart';

/// A read-only "wallet" card: a titled, grouped list of labelled rows, each
/// referencing a piece of some note.
///
/// Persisted as an `HmmNote`'s content under the `Hmm.CheatsheetMan.Cheatsheet`
/// catalog; see `LocalCheatsheetRepository`. Deliberately absent in v1:
/// `quickAccess` (the Quick Access Panel is an action-button registry, not a
/// card surface) and `sortOrder`/user reordering — the wallet orders
/// deterministically by title then id instead.
class CheatsheetCard {
  const CheatsheetCard({
    required this.id,
    required this.title,
    required this.walletGroup,
    required this.tags,
    required this.templateId,
    required this.rows,
    this.protected = false,
  });

  /// Stable v4 UUID minted once at create time and never regenerated on edit.
  /// Also the note's subject (`Cheatsheet:{id}`), so it must not track the
  /// mutable, non-unique [title].
  final String id;

  final String title;
  final String walletGroup;
  final List<String> tags;
  final String templateId;

  /// Phase-2 reserved (biometric/PIN gating). Not surfaced in any v1 UI.
  final bool protected;

  final List<CheatsheetRow> rows;

  CheatsheetCard copyWith({
    String? id,
    String? title,
    String? walletGroup,
    List<String>? tags,
    String? templateId,
    bool? protected,
    List<CheatsheetRow>? rows,
  }) =>
      CheatsheetCard(
        id: id ?? this.id,
        title: title ?? this.title,
        walletGroup: walletGroup ?? this.walletGroup,
        tags: tags ?? this.tags,
        templateId: templateId ?? this.templateId,
        protected: protected ?? this.protected,
        rows: rows ?? this.rows,
      );

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheatsheetCard &&
        other.id == id &&
        other.title == title &&
        other.walletGroup == walletGroup &&
        other.templateId == templateId &&
        other.protected == protected &&
        _sameList(other.tags, tags) &&
        _sameList(other.rows, rows);
  }

  @override
  int get hashCode => Object.hash(id, title, walletGroup, templateId, protected,
      Object.hashAll(tags), Object.hashAll(rows));

  @override
  String toString() => 'CheatsheetCard(id: $id, title: $title, '
      'walletGroup: $walletGroup, tags: $tags, templateId: $templateId, '
      'protected: $protected, rows: ${rows.length})';
}
