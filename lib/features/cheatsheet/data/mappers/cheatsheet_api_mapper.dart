import 'package:flutter/foundation.dart';

import '../../domain/entities/cheatsheet_card.dart';
import '../../domain/entities/cheatsheet_row.dart';
import '../../domain/entities/cheatsheet_source.dart';

/// Translates cheatsheet cards to and from the `/v1/cheatsheets` wire format.
///
/// Two things make this different from [CheatsheetCodec], which handles the
/// same card as *note content*:
///
/// * **The API is PascalCase.** `Startup.cs` calls `AddNewtonsoftJson()` with
///   the camel-case contract resolver left commented out, so the wire keys are
///   `Title` / `WalletGroup` / `Rows`, while note content uses `title` /
///   `walletGroup` / `rows`. Getting this wrong does not fail loudly - every
///   field simply reads back empty.
/// * **The server preserves what it cannot model, and so must we.** A row this
///   version cannot decode is kept in [CheatsheetCard.unreadableRows] and
///   written back untouched, so an unrelated edit cannot erase it.
class CheatsheetApiMapper {
  const CheatsheetApiMapper._();

  static const _schemaVersion = 1;

  static Map<String, dynamic> toApi(CheatsheetCard c) => {
        'Id': c.id,
        'SchemaVersion': _schemaVersion,
        'Title': c.title,
        'WalletGroup': c.walletGroup,
        'Tags': c.tags,
        'TemplateId': c.templateId,
        'Protected': c.protected,
        // Undecodable rows ride along verbatim. Saving rewrites the whole card,
        // so omitting them here would delete them on the next unrelated edit.
        'Rows': [
          ...c.rows.map(_rowToApi),
          ...c.unreadableRows,
        ],
      };

  static CheatsheetCard fromApi(Map<String, dynamic> m) {
    final rows = <CheatsheetRow>[];
    final unreadable = <Map<String, dynamic>>[];
    var index = 0;
    for (final e in _list(m['Rows'])) {
      try {
        rows.add(_rowFromApi((e as Map).cast<String, dynamic>()));
      } catch (err) {
        // Keep, don't drop: one row this version cannot read must not cost the
        // card, nor be quietly erased by the next save.
        final kept = e is Map;
        if (kept) unreadable.add(e.cast<String, dynamic>());
        debugPrint(
          'CheatsheetApiMapper: card ${_str(m['Id'])} row $index is unreadable '
          '($err); ${kept ? 'preserved verbatim' : 'dropped - not a map'}.',
        );
      }
      index++;
    }

    return CheatsheetCard(
      id: _str(m['Id']) ?? '',
      title: _str(m['Title']) ?? '',
      walletGroup: _str(m['WalletGroup']) ?? 'Ungrouped',
      tags: _list(m['Tags']).whereType<String>().toList(),
      templateId: _str(m['TemplateId']) ?? 'blank',
      protected: _bool(m['Protected']) ?? false,
      rows: rows,
      unreadableRows: unreadable,
    );
  }

  /// `as List?` would throw on a non-list; a server on a newer schema may send
  /// anything, and a type error here would take out the whole wallet.
  static List<Object?> _list(Object? v) => v is List ? v : const [];

  static String? _str(Object? v) => v is String ? v : null;

  static bool? _bool(Object? v) => v is bool ? v : null;

  static Map<String, dynamic> _rowToApi(CheatsheetRow r) => {
        'Label': r.label,
        'ValueAction': r.valueAction.name,
        'OpenSource': r.openSource,
        if (r.source != null) 'Source': _srcToApi(r.source!),
      };

  static CheatsheetRow _rowFromApi(Map<String, dynamic> m) => CheatsheetRow(
        label: _str(m['Label']) ?? '',
        source: m['Source'] == null
            ? null
            // A non-map Source throws, which drops just this row into
            // unreadableRows rather than losing it.
            : _srcFromApi((m['Source'] as Map).cast<String, dynamic>()),
        valueAction: ValueAction.values.firstWhere(
          (v) => v.name == m['ValueAction'],
          orElse: () => ValueAction.none,
        ),
        openSource: _bool(m['OpenSource']) ?? true,
      );

  static Map<String, dynamic> _srcToApi(CheatsheetSource s) => {
        'NoteUuid': s.noteUuid,
        'Kind': s.kind.name,
        if (s.locator != null) 'Locator': s.locator,
      };

  static CheatsheetSource _srcFromApi(Map<String, dynamic> m) =>
      CheatsheetSource(
        noteUuid: _str(m['NoteUuid']) ?? '',
        kind: SourceGranularity.values.firstWhere(
          (k) => k.name == m['Kind'],
          orElse: () => SourceGranularity.whole,
        ),
        locator: _str(m['Locator']),
      );
}
