import '../../../../core/data/attachments/attachment_ref.dart';
import 'card_style.dart';
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
    this.unreadableRows = const [],
    this.style = CardStyle.empty,
    this.cover,
    this.extraFields = const {},
  });

  /// Stable v4 UUID minted once at create time and never regenerated on edit.
  /// Also the note's subject (`Cheatsheet:{id}`), so it must not track the
  /// mutable, non-unique [title].
  final String id;

  final String title;
  final String walletGroup;
  final List<String> tags;
  final String templateId;

  /// Phase-2 reserved (biometric/PIN gating). Not surfaced in any v1 UI. A
  /// protected card's cover is stored as a sensitive attachment.
  final bool protected;

  final List<CheatsheetRow> rows;

  /// Rows the codec could not decode, kept verbatim.
  ///
  /// Saving rewrites the whole card, so a row dropped at read time would be
  /// erased by the next unrelated edit. Carrying the raw maps through means a
  /// save can't destroy data this version didn't understand — a newer client,
  /// or a fixed decoder, can still read them.
  final List<Map<String, dynamic>> unreadableRows;

  /// The stored look (raw; see [CardStyle]). Empty for a card whose look was
  /// never changed — it renders its template default.
  final CardStyle style;

  /// Read-through projection of the cover attachment in the owning note's
  /// `attachments` column, matched by `style.cover`. Null when there is no
  /// cover or its ref is not in the column. The bytes are NEVER referenced
  /// from content: `VaultGc` reads only the attachments column.
  final VaultRef? cover;

  /// Card keys this version does not model, written back unchanged.
  final Map<String, dynamic> extraFields;

  /// What the card renders with: [style] where valid, template defaults
  /// everywhere else.
  CardLook get look => style.resolve(templateId);

  /// Sets or clears the cover, keeping `style.cover` and [cover] in step.
  CheatsheetCard withCover(VaultRef? ref) => copyWith(
        style: style.withCoverPath(ref?.path),
        cover: ref,
        clearCover: ref == null,
      );

  CheatsheetCard copyWith({
    String? id,
    String? title,
    String? walletGroup,
    List<String>? tags,
    String? templateId,
    bool? protected,
    List<CheatsheetRow>? rows,
    List<Map<String, dynamic>>? unreadableRows,
    CardStyle? style,
    VaultRef? cover,
    bool clearCover = false,
    Map<String, dynamic>? extraFields,
  }) =>
      CheatsheetCard(
        id: id ?? this.id,
        title: title ?? this.title,
        walletGroup: walletGroup ?? this.walletGroup,
        tags: tags ?? this.tags,
        templateId: templateId ?? this.templateId,
        protected: protected ?? this.protected,
        rows: rows ?? this.rows,
        unreadableRows: unreadableRows ?? this.unreadableRows,
        style: style ?? this.style,
        cover: clearCover ? null : (cover ?? this.cover),
        extraFields: extraFields ?? this.extraFields,
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
        _sameList(other.rows, rows) &&
        // Part of the value: two cards are not the same card if one carries
        // rows this version couldn't parse and the other doesn't.
        _sameMapList(other.unreadableRows, unreadableRows) &&
        other.style == style &&
        other.cover == cover &&
        jsonValueEquals(other.extraFields, extraFields);
  }

  static bool _sameMapList(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (final entry in a[i].entries) {
        if (!b[i].containsKey(entry.key) || b[i][entry.key] != entry.value) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        walletGroup,
        templateId,
        protected,
        Object.hashAll(tags),
        Object.hashAll(rows),
        unreadableRows.length,
        style,
        cover,
        jsonValueHash(extraFields),
      );

  @override
  String toString() => 'CheatsheetCard(id: $id, title: $title, '
      'walletGroup: $walletGroup, tags: $tags, templateId: $templateId, '
      'protected: $protected, rows: ${rows.length}, '
      'unreadableRows: ${unreadableRows.length}, style: $style, '
      'cover: ${cover != null}, extraKeys: ${extraFields.keys.toList()})';
}
