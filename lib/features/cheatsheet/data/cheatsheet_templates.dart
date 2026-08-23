import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/cheatsheet_card.dart';
import '../domain/entities/cheatsheet_row.dart';

/// A starting shape for a new card: a title, a wallet group, and the row
/// labels worth having. Templates carry **no bindings** — the point is to give
/// somebody the questions, then let them answer each one by pointing at a note.
///
/// ## What gets translated here, and what does not
///
/// Both `walletGroup` and every row label are copied into the saved card and
/// persisted by `CheatsheetCodec`, so each raises the same question this app
/// has hit in every feature: *is this string for a person, or for the
/// machine?* The answers differ, and the split is deliberate.
///
/// **Row labels ARE translated.** They seed a document. Once instantiated they
/// are ordinary editable content — the user renames them freely, and nothing
/// anywhere matches on a label (`CheatsheetRow.label` appears only in `==`).
/// Seeding "Plate" onto a card created by a Chinese user would hand them an
/// English form to retype; seeding 车牌号 is the whole point.
///
/// **`walletGroup` is NOT translated.** The wallet groups cards with
/// `groups.putIfAbsent(c.walletGroup, …)` — an exact string match. A translated
/// seed would put cards created before and after a language change into two
/// groups that should be one, silently. So the stored value stays the English
/// key and [cheatsheetGroupLabel] translates it for display; a group the user
/// types themselves is shown exactly as typed.
class CheatsheetTemplate {
  const CheatsheetTemplate({
    required this.id,
    required this.title,
    required this.walletGroup,
    required this.rowLabels,
  });

  final String id;

  /// Chooser copy, and the card's starting title. Editable from there.
  final String title;

  /// Stored verbatim on the card. English key by design; see the class doc.
  final String walletGroup;

  /// Seed labels for the card's rows. Translated, because they become the
  /// user's own document content.
  final List<String> rowLabels;
}

class CheatsheetTemplates {
  const CheatsheetTemplates._();

  /// The templates, with copy resolved for [l].
  ///
  /// A method rather than a `const` list because the titles and row labels are
  /// localized. `id` and `walletGroup` stay literals.
  static List<CheatsheetTemplate> all(AppLocalizations l) => [
        CheatsheetTemplate(
          id: 'accidentClaim',
          title: l.cheatsheetTemplateAccidentClaim,
          walletGroup: 'Vehicle',
          rowLabels: [
            l.cheatsheetRowPlate,
            l.cheatsheetRowVin,
            l.cheatsheetRowInsurer,
            l.cheatsheetRowPolicyNumber,
            l.cheatsheetRowDriver,
            l.cheatsheetRowPhone,
            l.cheatsheetRowAddress,
          ],
        ),
        CheatsheetTemplate(
          id: 'healthInfo',
          title: l.cheatsheetTemplateHealthInfo,
          walletGroup: 'Health',
          rowLabels: [
            l.cheatsheetRowPerson,
            l.cheatsheetRowFamilyDoctor,
            l.cheatsheetRowDoctorPhone,
            l.cheatsheetRowPharmacy,
            l.cheatsheetRowPharmacyPhone,
            l.cheatsheetRowAddress,
          ],
        ),
        CheatsheetTemplate(
          id: 'document',
          title: l.cheatsheetTemplateDocument,
          walletGroup: 'Reference',
          rowLabels: [l.cheatsheetRowSection1],
        ),
        CheatsheetTemplate(
          id: 'blank',
          title: l.cheatsheetTemplateBlank,
          walletGroup: 'Ungrouped',
          rowLabels: const [],
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

/// Display label for a card's `walletGroup`.
///
/// Translates the four values the templates seed; anything else — a group the
/// user typed — is returned unchanged, because it is already in whatever
/// language they wrote it in.
String cheatsheetGroupLabel(String group, AppLocalizations l) =>
    switch (group) {
      'Vehicle' => l.cheatsheetGroupVehicle,
      'Health' => l.cheatsheetGroupHealth,
      'Reference' => l.cheatsheetGroupReference,
      'Ungrouped' => l.cheatsheetGroupUngrouped,
      _ => group,
    };
