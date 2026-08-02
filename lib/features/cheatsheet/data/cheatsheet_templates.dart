import '../domain/entities/cheatsheet_card.dart';
import '../domain/entities/cheatsheet_row.dart';

/// A starting shape for a new card: a title, a wallet group, and the row
/// labels worth having. Templates carry **no bindings** — the point is to give
/// somebody the questions, then let them answer each one by pointing at a note.
class CheatsheetTemplate {
  const CheatsheetTemplate({
    required this.id,
    required this.title,
    required this.walletGroup,
    required this.rowLabels,
  });

  final String id;
  final String title;
  final String walletGroup;
  final List<String> rowLabels;
}

class CheatsheetTemplates {
  const CheatsheetTemplates._();

  static const all = <CheatsheetTemplate>[
    CheatsheetTemplate(
      id: 'accidentClaim',
      title: 'Accident Claim',
      walletGroup: 'Vehicle',
      rowLabels: [
        'Plate',
        'VIN',
        'Insurer',
        'Policy #',
        'Driver',
        'Phone',
        'Address',
      ],
    ),
    CheatsheetTemplate(
      id: 'healthInfo',
      title: 'Health Info',
      walletGroup: 'Health',
      rowLabels: [
        'Person',
        'Family doctor',
        'Doctor phone',
        'Pharmacy',
        'Pharmacy phone',
        'Address',
      ],
    ),
    CheatsheetTemplate(
      id: 'document',
      title: 'Document',
      walletGroup: 'Reference',
      rowLabels: ['Section 1'],
    ),
    CheatsheetTemplate(
      id: 'blank',
      title: 'Blank',
      walletGroup: 'Ungrouped',
      rowLabels: [],
    ),
  ];

  /// Builds an all-unbound card from [t].
  ///
  /// The [id] comes from the caller — id generation belongs to the editor
  /// (`cheatsheetIdGenProvider`), so this stays a pure shape factory and
  /// tests can pin identity without a seam of their own.
  static CheatsheetCard instantiate(CheatsheetTemplate t, String id) =>
      CheatsheetCard(
        id: id,
        title: t.title,
        walletGroup: t.walletGroup,
        tags: const [],
        templateId: t.id,
        rows: t.rowLabels
            .map((l) => CheatsheetRow(label: l, source: null))
            .toList(),
      );
}
