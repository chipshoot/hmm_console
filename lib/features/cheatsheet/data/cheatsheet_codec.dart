import 'package:flutter/foundation.dart';

import '../domain/entities/cheatsheet_card.dart';
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';

/// Card <-> JSON map. The map is what `LocalCheatsheetRepository` nests under
/// the note-content envelope, so it is **persisted data**: decode defensively.
///
/// Two rules hold the line against data loss:
/// * a malformed *row* is dropped on its own — never the whole card;
/// * every scalar read is type-checked and falls back to a default rather
///   than throwing, so a serializer change or a hand-edited note degrades to
///   a partial card instead of an invisible one.
class CheatsheetCodec {
  /// Bump when the persisted shape changes incompatibly, and branch on
  /// [schemaVersionOf] here. v1 is the only known shape today; newer versions
  /// decode best-effort through the defensive readers below.
  static const currentSchemaVersion = 1;

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
      };

  static CheatsheetCard fromMap(Map<String, dynamic> m) {
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
          '($err); ${kept ? 'preserved verbatim and re-saved untouched' : 'dropped — not a map'}.',
        );
      }
      index++;
    }
    return CheatsheetCard(
      unreadableRows: unreadable,
      id: _str(m['id']) ?? '',
      title: _str(m['title']) ?? '',
      walletGroup: _str(m['walletGroup']) ?? 'Ungrouped',
      tags: _list(m['tags']).whereType<String>().toList(),
      templateId: _str(m['templateId']) ?? 'blank',
      protected: _bool(m['protected']) ?? false,
      rows: rows,
    );
  }

  /// `as List?` would throw on a non-list; persisted data may hold anything.
  static List<Object?> _list(Object? v) => v is List ? v : const [];

  static String? _str(Object? v) => v is String ? v : null;

  static bool? _bool(Object? v) => v is bool ? v : null;

  static Map<String, dynamic> _rowToMap(CheatsheetRow r) => {
        'label': r.label,
        'valueAction': r.valueAction.name,
        'openSource': r.openSource,
        if (r.source != null) 'source': _srcToMap(r.source!),
      };

  static CheatsheetRow _rowFromMap(Map<String, dynamic> m) => CheatsheetRow(
        label: _str(m['label']) ?? '',
        source: m['source'] == null
            ? null
            // A non-map source throws here, dropping just this row.
            : _srcFromMap((m['source'] as Map).cast<String, dynamic>()),
        valueAction: ValueAction.values.firstWhere(
          (v) => v.name == m['valueAction'],
          orElse: () => ValueAction.none,
        ),
        openSource: _bool(m['openSource']) ?? true,
      );

  static Map<String, dynamic> _srcToMap(CheatsheetSource s) => {
        'noteUuid': s.noteUuid,
        'kind': s.kind.name,
        if (s.locator != null) 'locator': s.locator,
      };

  static CheatsheetSource _srcFromMap(Map<String, dynamic> m) =>
      CheatsheetSource(
        noteUuid: _str(m['noteUuid']) ?? '',
        kind: SourceGranularity.values.firstWhere(
          (k) => k.name == m['kind'],
          orElse: () => SourceGranularity.whole,
        ),
        locator: _str(m['locator']),
      );
}
