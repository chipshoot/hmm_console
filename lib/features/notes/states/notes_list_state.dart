import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local/database.dart';
import '../../../core/data/repository_providers.dart';
import '../../../core/notes/catalog_palette.dart';
import '../data/models/hmm_note.dart';
import '../data/subsystem_anchor.dart';

enum NoteSort { dateNewest, dateOldest, lastModified, subjectAZ }

const Object _unset = Object();

/// Normalizes a domain key to its subsystem-anchor key form, mirroring how
/// [CatalogPalette.domainStyle] strips a trailing "Man": `AutomobileMan` ->
/// `automobile` (which matches the `hmm-subsystem-automobile` anchor uuid).
String _normalizeDomainKey(String key) =>
    (key.endsWith('Man') && key.length > 3
            ? key.substring(0, key.length - 3)
            : key)
        .toLowerCase();

/// What a note needs to know about the note it is attached to: the domain
/// that note belongs to, and what to call it on screen.
typedef AttachTarget = ({String domain, String subject});

class NotesListData {
  const NotesListData({
    required this.all,
    required this.catalogsById,
    this.catalogFilter,
    this.sort = NoteSort.dateNewest,
    this.query = '',
    this.catalogDomainById = const {},
    this.anchorDomainById = const {},
    this.targetsById = const {},
  });

  final List<HmmNote> all;
  final Map<int, NoteCatalog> catalogsById;
  final Set<int>? catalogFilter; // null = all
  final NoteSort sort;
  final String query;

  /// catalog id -> its domain key (e.g. `Hmm.AutomobileMan.GasLog` ->
  /// `AutomobileMan`). Lets the filter resolve a selection back to domains.
  final Map<int, String> catalogDomainById;

  /// Subsystem-anchor note id -> the catalog domain it represents (e.g. the
  /// `automobile` anchor -> `AutomobileMan`). Lets the domain filter also match
  /// General notes attached to that subsystem via parentNoteId.
  final Map<int, String> anchorDomainById;

  /// Note id -> the domain and subject of a note others can attach to (a
  /// car, a policy, a book). Every typed record carries its domain in its
  /// own catalog name, so this needs no per-domain knowledge.
  final Map<int, AttachTarget> targetsById;

  Map<int, int> get countsByCatalog {
    final m = <int, int>{};
    for (final n in all) {
      final c = n.catalogId;
      if (c != null) m[c] = (m[c] ?? 0) + 1;
    }
    return m;
  }

  /// The domain of the thing this note is attached to, when that thing
  /// carries one: a subsystem anchor, or any typed record such as a car.
  String? parentDomainOf(HmmNote n) {
    final p = n.parentNoteId;
    if (p == null) return null;
    return anchorDomainById[p] ?? targetsById[p]?.domain;
  }

  String? ownDomainOf(HmmNote n) =>
      n.catalogId == null ? null : catalogDomainById[n.catalogId];

  /// Where the note lives: what it is attached to, falling back to its own
  /// catalog. A dangling parent resolves to neither, so the note keeps its
  /// catalog's domain rather than vanishing from every filter.
  String? effectiveDomain(HmmNote n) => parentDomainOf(n) ?? ownDomainOf(n);

  /// The parent's subject, for the row and for search. Null when unattached,
  /// and for an anchor parent (anchors are not in the loaded set).
  String? contextSubjectOf(HmmNote n) {
    final p = n.parentNoteId;
    return p == null ? null : targetsById[p]?.subject;
  }

  List<HmmNote> get visible {
    Iterable<HmmNote> items = all;
    final f = catalogFilter;
    if (f != null && f.isNotEmpty) {
      // Domains represented by the selected catalogs. A note matches if its
      // catalog is selected OR it's attached to something whose domain is
      // among them (so "Automobile" surfaces notes attached to the
      // automobile subsystem, not just automobile-catalog notes).
      final selectedDomains = <String>{
        for (final id in f)
          if (catalogDomainById[id] != null) catalogDomainById[id]!,
      };
      items = items.where((n) {
        final own = ownDomainOf(n);
        final parent = parentDomainOf(n);
        // Attached to something in ANOTHER domain — a General note under a
        // car. It lives there and nowhere else, so General keeps meaning
        // "attached to nothing in particular". This is what the code already
        // did for notes attached to a subsystem anchor; cars now count too.
        if (parent != null && parent != own) {
          return selectedDomains.contains(parent);
        }
        // Otherwise the note is a record of its own domain, so it filters by
        // its exact catalog: picking "Insurance" must not drag in every note
        // that happens to hang off a car.
        return n.catalogId != null && f.contains(n.catalogId);
      });
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((n) =>
          n.subject.toLowerCase().contains(q) ||
          (contextSubjectOf(n)?.toLowerCase().contains(q) ?? false));
    }
    final list = items.toList();
    switch (sort) {
      case NoteSort.dateNewest:
        list.sort((a, b) => b.effectiveNoteDate.compareTo(a.effectiveNoteDate));
      case NoteSort.dateOldest:
        list.sort((a, b) => a.effectiveNoteDate.compareTo(b.effectiveNoteDate));
      case NoteSort.lastModified:
        list.sort((a, b) => (b.lastModifiedDate ?? b.effectiveNoteDate)
            .compareTo(a.lastModifiedDate ?? a.effectiveNoteDate));
      case NoteSort.subjectAZ:
        list.sort((a, b) =>
            a.subject.toLowerCase().compareTo(b.subject.toLowerCase()));
    }
    return list;
  }

  NotesListData copyWith({
    List<HmmNote>? all,
    Map<int, NoteCatalog>? catalogsById,
    Object? catalogFilter = _unset,
    NoteSort? sort,
    String? query,
    Map<int, String>? catalogDomainById,
    Map<int, String>? anchorDomainById,
    Map<int, AttachTarget>? targetsById,
  }) {
    return NotesListData(
      all: all ?? this.all,
      catalogsById: catalogsById ?? this.catalogsById,
      catalogFilter: identical(catalogFilter, _unset)
          ? this.catalogFilter
          : catalogFilter as Set<int>?,
      sort: sort ?? this.sort,
      query: query ?? this.query,
      catalogDomainById: catalogDomainById ?? this.catalogDomainById,
      anchorDomainById: anchorDomainById ?? this.anchorDomainById,
      targetsById: targetsById ?? this.targetsById,
    );
  }
}

/// Reactive feed of the current author's live notes. Emits on every change to
/// the Notes table — so notes written by ANY feature (gas log, automobile, …)
/// flow into the list without manual invalidation.
final _notesStreamProvider = StreamProvider.autoDispose<List<HmmNote>>((ref) {
  return ref.watch(hmmNoteRepositoryProvider).watchNotes();
});

/// Reactive feed of catalogs (a domain feature creates its catalog lazily on
/// first write, so the catalog set can change too).
final _catalogsStreamProvider =
    StreamProvider.autoDispose<List<NoteCatalog>>((ref) {
  return ref.watch(noteCatalogRepositoryProvider).watchCatalogs();
});

class NotesListState extends AsyncNotifier<NotesListData> {
  // View criteria live on the notifier so they survive reactive data
  // emissions (which refresh the data, not the user's filter/sort/search).
  Set<int>? _filter;
  NoteSort _sort = NoteSort.dateNewest;
  String _query = '';

  @override
  Future<NotesListData> build() async {
    final notes = await ref.watch(_notesStreamProvider.future);
    final catalogs = await ref.watch(_catalogsStreamProvider.future);
    final anchorMatches =
        catalogs.where((c) => c.name == kSubsystemAnchorCatalogName);
    final anchorCatalogId =
        anchorMatches.isEmpty ? null : anchorMatches.first.id;
    // Exclude the internal subsystem-anchor catalog from the catalog map so it
    // never surfaces as a user-facing "System" filter.
    final byId = {
      for (final c in catalogs)
        if (c.id != anchorCatalogId) c.id: c,
    };
    final visibleNotes = anchorCatalogId == null
        ? notes
        : notes.where((n) => n.catalogId != anchorCatalogId).toList();

    // catalog id -> domain key, and subsystem-anchor note id -> the domain it
    // represents (linking the `automobile` anchor to the `AutomobileMan`
    // domain so attached notes surface under that filter).
    final catalogDomainById = {
      for (final c in catalogs) c.id: CatalogPalette.domainKeyFor(c.name),
    };
    final anchorDomainById = <int, String>{};
    if (anchorCatalogId != null) {
      const prefix = 'hmm-subsystem-';
      final domains = catalogDomainById.values.toSet();
      for (final n in notes.where((n) => n.catalogId == anchorCatalogId)) {
        if (!n.uuid.startsWith(prefix)) continue;
        final anchorKey = n.uuid.substring(prefix.length);
        for (final d in domains) {
          if (_normalizeDomainKey(d) == anchorKey) {
            anchorDomainById[n.id] = d;
            break;
          }
        }
      }
    }

    // Anything with a domain of its own can be attached to, so a note under
    // it borrows that domain. Built from the notes already loaded: no query.
    final targetsById = {
      for (final n in visibleNotes)
        if (n.catalogId != null && catalogDomainById[n.catalogId] != null)
          n.id: (
            domain: catalogDomainById[n.catalogId]!,
            subject: n.subject,
          ),
    };

    return NotesListData(
      all: visibleNotes,
      catalogsById: byId,
      catalogFilter: _filter,
      sort: _sort,
      query: _query,
      catalogDomainById: catalogDomainById,
      anchorDomainById: anchorDomainById,
      targetsById: targetsById,
    );
  }

  void setSort(NoteSort sort) {
    _sort = sort;
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(sort: sort));
  }

  void setQuery(String query) {
    _query = query;
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(query: query));
  }

  void setFilter(Set<int>? catalogIds) {
    _filter = catalogIds;
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(catalogFilter: catalogIds));
  }

  /// Pull-to-refresh hook. The list already updates reactively, so this just
  /// re-subscribes the underlying streams; harmless if invoked.
  Future<void> refresh() async {
    ref.invalidate(_notesStreamProvider);
    ref.invalidate(_catalogsStreamProvider);
  }
}

final notesListStateProvider =
    AsyncNotifierProvider<NotesListState, NotesListData>(
  () => NotesListState(),
);
