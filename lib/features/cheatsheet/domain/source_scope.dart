import '../../notes/data/models/hmm_note.dart';

/// Which notes a cheatsheet row can bind to, and in what order to offer them.
///
/// The picker used to fetch every note in every catalog and list them flat.
/// On an Accident Claim that meant scrolling past unrelated notes to reach the
/// vehicle — and, worse, past the app's own bookkeeping notes, which are not
/// sources at all.
///
/// Pure and dependency-free on purpose: the rules are the part worth testing,
/// and they should be testable without a database, a router or a widget tree.

/// Catalogs holding the app's own records rather than anything a person wrote.
///
/// * `Hmm.CheatsheetMan.Cheatsheet` — cheatsheet cards are themselves stored as
///   notes (subject `Cheatsheet:{id}`), so leaving this in meant every card you
///   saved came back as something to reference, and the list grew with use.
/// * `Hmm.System.Subsystem` — anchor notes that exist only so General notes
///   have something to hang off.
///
/// Names are duplicated rather than imported: the definitions live in
/// `core/data/local/local_cheatsheet_repository.dart` and
/// `features/notes/data/subsystem_anchor.dart`, both of which pull in Drift and
/// Riverpod. `source_scope_test.dart` asserts these stay equal to the originals,
/// so the copy cannot drift unnoticed.
const kInfrastructureCatalogNames = <String>{
  'Hmm.CheatsheetMan.Cheatsheet',
  'Hmm.System.Subsystem',
};

/// The subject areas a card can draw from.
///
/// An identifier rather than a display string: this layer decides which notes
/// belong together, and should not also decide what English word goes above
/// them. `SourcePicker` maps these to headings, which is where the copy — and
/// one day its translations — belongs.
enum SourceDomainId { vehicle }

/// The subject area a template draws from: which domain it is, and the catalog
/// prefix whose notes belong to that domain.
///
/// A prefix rather than an exact name because one domain spans several
/// catalogs — a vehicle claim wants `AutomobileInfo`, `AutoInsurancePolicy` and
/// `ServiceRecord` alike, all namespaced `Hmm.AutomobileMan.`.
class SourceDomain {
  const SourceDomain({required this.id, required this.catalogPrefix});

  final SourceDomainId id;
  final String catalogPrefix;
}

/// The domain [templateId] draws from, or null when it has no home domain.
///
/// Only `accidentClaim` maps to one today. `healthInfo` and `document`
/// deliberately do not: this app has no health or document catalogs, so
/// claiming a domain for them would rank nothing and put a heading over an
/// empty group. Add an entry here when the matching catalogs exist.
///
/// Keyed on `templateId`, not `walletGroup`: the wallet group is a free-text
/// field the user edits, so keying on it would make scoping change under them
/// as they typed.
SourceDomain? sourceDomainFor(String templateId) => switch (templateId) {
      'accidentClaim' => const SourceDomain(
          id: SourceDomainId.vehicle,
          catalogPrefix: 'Hmm.AutomobileMan.',
        ),
      _ => null,
    };

/// Notes split into what to offer first and what to offer after.
class ScopedSourceNotes {
  const ScopedSourceNotes({required this.preferred, required this.other});

  /// Notes in the card's own domain. Empty when the template has no domain.
  final List<HmmNote> preferred;

  /// Everything else still worth binding to.
  final List<HmmNote> other;
}

/// Ranks [all] for a card in [domain], dropping only infrastructure notes.
///
/// Ranking rather than filtering is deliberate. The Accident Claim template
/// asks for Driver, Phone and Address, which live in a General note, not a
/// vehicle one — a hard filter to the vehicle domain would leave three of its
/// seven rows impossible to fill. So the domain is surfaced first and the rest
/// stays reachable below it.
///
/// [catalogNames] maps catalog id to catalog name. A note whose catalog is
/// absent from the map — or which has no catalog at all — is kept, in [other]:
/// unknown means "not ranked", never "hidden", because hiding a note is exactly
/// the failure this function exists to prevent.
///
/// Input order is preserved within each group; the repository already sorts by
/// last-modified and that is worth keeping.
ScopedSourceNotes scopeSourceNotes({
  required List<HmmNote> all,
  required Map<int, String> catalogNames,
  required SourceDomain? domain,
}) {
  final preferred = <HmmNote>[];
  final other = <HmmNote>[];

  for (final note in all) {
    final catalogId = note.catalogId;
    final name = catalogId == null ? null : catalogNames[catalogId];

    if (name != null && kInfrastructureCatalogNames.contains(name)) continue;

    if (domain != null &&
        name != null &&
        name.startsWith(domain.catalogPrefix)) {
      preferred.add(note);
    } else {
      other.add(note);
    }
  }

  return ScopedSourceNotes(preferred: preferred, other: other);
}
