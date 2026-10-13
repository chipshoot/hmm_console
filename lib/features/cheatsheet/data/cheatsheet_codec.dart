import 'package:flutter/foundation.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../domain/entities/card_style.dart';
import '../domain/entities/cheatsheet_card.dart';
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';

/// Card <-> JSON map. The map is what `LocalCheatsheetRepository` nests under
/// the note-content envelope, so it is **persisted data**: decode defensively.
///
/// Rules that hold the line against data loss:
/// * a malformed *row* is dropped on its own — never the whole card;
/// * every scalar read is type-checked and falls back to a default rather
///   than throwing, so a serializer change or a hand-edited note degrades to
///   a partial card instead of an invisible one;
/// * keys this version does not model — on the card, on a row, inside
///   `style` — are carried through and written back unchanged;
/// * the write order is fixed (known keys, then `style`, then unknown keys),
///   so a card read and saved without edits is byte-identical. The backend
///   serializer writes the same order.
class CheatsheetCodec {
  /// Bump when the persisted shape changes incompatibly, and branch on
  /// [schemaVersionOf] here. v1 is the only known shape today; newer versions
  /// decode best-effort through the defensive readers below. `style` and row
  /// `emoji` are optional additions to v1, not a new version: an older reader
  /// that ignores them still reads the card.
  static const currentSchemaVersion = 1;

  static const _styleKey = 'style';
  static const _emojiKey = 'emoji';
  static const _cardKeys = {
    'schemaVersion',
    'id',
    'title',
    'walletGroup',
    'tags',
    'templateId',
    'protected',
    'rows',
  };
  static const _rowKeys = {'label', 'valueAction', 'openSource', 'source'};

  static int schemaVersionOf(Map<String, dynamic> m) =>
      (m['schemaVersion'] as num?)?.toInt() ?? 1;

  static Map<String, dynamic> toMap(CheatsheetCard c) => {
        'schemaVersion': currentSchemaVersion,
        'id': c.id,
        'title': c.title,
        'walletGroup': c.walletGroup,
        'tags': c.tags,
        'templateId': c.templateId,
        'protected': c.protected,
        // Unreadable rows are written back untouched: a save must not destroy
        // rows this version couldn't parse.
        'rows': [
          ...c.rows.map(_rowToMap),
          ...c.unreadableRows,
        ],
        if (!c.style.isEmpty) _styleKey: c.style.toMap(),
        for (final e in c.extraFields.entries)
          // A preserved non-map `style` yields to a real one the user set.
          if (!_cardKeys.contains(e.key) &&
              !(e.key == _styleKey && !c.style.isEmpty))
            e.key: e.value,
      };

  /// [attachments] is the owning note's attachments column; the cover is the
  /// vault ref there whose path `style.cover` names. Without it (or without a
  /// match) the card has no cover but keeps the stored path.
  static CheatsheetCard fromMap(
    Map<String, dynamic> m, {
    NoteAttachments? attachments,
  }) {
    final rows = <CheatsheetRow>[];
    final unreadable = <Map<String, dynamic>>[];
    var index = 0;
    for (final e in _list(m['rows'])) {
      try {
        rows.add(_rowFromMap((e as Map).cast<String, dynamic>()));
      } catch (err) {
        // Keep, don't drop. One bad row must never lose the whole card — and
        // must not be silently erased by the next save either.
        final kept = e is Map;
        if (kept) unreadable.add(e.cast<String, dynamic>());
        debugPrint(
          'CheatsheetCodec: card ${_str(m['id'])} row $index is unreadable '
          '(${err.runtimeType}); ${kept ? 'preserved verbatim and re-saved untouched' : 'dropped — not a map'}.',
        );
      }
      index++;
    }

    final rawStyle = m[_styleKey];
    final style = rawStyle is Map
        // Deep copy: CardStyle keeps its map by reference, so sharing the
        // decoded map (or a nested one) would let the caller's later
        // mutation change this card's look.
        ? CardStyle(_deepCopyMap(rawStyle))
        : CardStyle.empty;

    return CheatsheetCard(
      unreadableRows: unreadable,
      id: _str(m['id']) ?? '',
      title: _str(m['title']) ?? '',
      walletGroup: _str(m['walletGroup']) ?? 'Ungrouped',
      tags: _list(m['tags']).whereType<String>().toList(),
      templateId: _str(m['templateId']) ?? 'blank',
      protected: _bool(m['protected']) ?? false,
      rows: rows,
      style: style,
      cover: _coverFrom(style.coverPath, attachments),
      extraFields: {
        for (final e in m.entries)
          // A non-map `style` is not consumed: it rides along as an unknown.
          if (!_cardKeys.contains(e.key) &&
              !(e.key == _styleKey && rawStyle is Map))
            e.key: e.value,
      },
    );
  }

  static VaultRef? _coverFrom(String? path, NoteAttachments? a) {
    if (path == null || a == null) return null;
    final refs = <AttachmentRef?>[a.primaryImage, ...a.images, ...a.files];
    for (final r in refs) {
      if (r is VaultRef && r.path == path) return r;
    }
    return null;
  }

  /// A JSON-shaped copy with no map or list shared with [m].
  static Map<String, dynamic> _deepCopyMap(Map<dynamic, dynamic> m) => {
        for (final e in m.entries) e.key as String: _deepCopy(e.value),
      };

  static Object? _deepCopy(Object? v) => switch (v) {
        Map() => _deepCopyMap(v),
        List() => [for (final x in v) _deepCopy(x)],
        _ => v,
      };

  /// `as List?` would throw on a non-list; persisted data may hold anything.
  static List<Object?> _list(Object? v) => v is List ? v : const [];

  static String? _str(Object? v) => v is String ? v : null;

  static bool? _bool(Object? v) => v is bool ? v : null;

  static Map<String, dynamic> _rowToMap(CheatsheetRow r) => {
        'label': r.label,
        'valueAction': r.valueAction.name,
        'openSource': r.openSource,
        if (r.source != null) 'source': _srcToMap(r.source!),
        if (r.emoji != null) _emojiKey: r.emoji,
        for (final e in r.extraFields.entries)
          if (!_rowKeys.contains(e.key) &&
              !(e.key == _emojiKey && r.emoji != null))
            e.key: e.value,
      };

  static CheatsheetRow _rowFromMap(Map<String, dynamic> m) {
    final rawEmoji = m[_emojiKey];
    return CheatsheetRow(
      label: _str(m['label']) ?? '',
      source: m['source'] == null
          ? null
          // A non-map source throws here, dropping just this row.
          : _srcFromMap((m['source'] as Map).cast<String, dynamic>()),
      valueAction: m['valueAction'] == null
          ? ValueAction.none
          // An unrecognised value throws, so the row is preserved verbatim
          // rather than silently normalised to a different action.
          : ValueAction.values.firstWhere((v) => v.name == m['valueAction']),
      openSource: _bool(m['openSource']) ?? true,
      emoji: rawEmoji is String ? rawEmoji : null,
      extraFields: {
        for (final e in m.entries)
          // A non-string emoji is not consumed, so it survives as an unknown.
          if (!_rowKeys.contains(e.key) &&
              !(e.key == _emojiKey && rawEmoji is String))
            e.key: e.value,
      },
    );
  }

  static Map<String, dynamic> _srcToMap(CheatsheetSource s) => {
        'noteUuid': s.noteUuid,
        'kind': s.kind.name,
        if (s.locator != null) 'locator': s.locator,
      };

  static CheatsheetSource _srcFromMap(Map<String, dynamic> m) =>
      CheatsheetSource(
        noteUuid: _str(m['noteUuid']) ?? '',
        kind: m['kind'] == null
            ? SourceGranularity.whole
            // An unrecognised kind throws, so the row is preserved verbatim.
            : SourceGranularity.values.firstWhere((k) => k.name == m['kind']),
        locator: _str(m['locator']),
      );
}
