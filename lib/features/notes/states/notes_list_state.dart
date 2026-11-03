import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local/database.dart';
import '../../../core/data/local/local_tag_repository.dart' show NoteTagLabel;
import '../../../core/data/repository_providers.dart';
import '../../../core/notes/note_state.dart';
import '../../../core/notes/catalog_palette.dart';
import '../data/models/hmm_note.dart';
import '../data/subsystem_anchor.dart';
import '../query/note_query.dart';

export '../query/note_query.dart' show NoteSort;
export '../../../core/data/local/local_tag_repository.dart' show NoteTagLabel;

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
    this.statesByUuid = const {},
    this.tagsByNoteId = const {},
    this.query = const NoteQuery.initial(),
    this.catalogDomainById = const {},
    this.anchorDomainById = const {},
    this.targetsById = const {},
    this.liveTagNames,
  });

  final List<HmmNote> all;
  final Map<int, NoteCatalog> catalogsById;

  /// Pin + flag per note uuid (G14); a note without a row has none.
  final Map<String, NoteState> statesByUuid;

  /// Note id -> its active tags, by name.
  final Map<int, List<NoteTagLabel>> tagsByNoteId;

  /// What the list is asked to show; lives on the notifier.
  final NoteQuery query;

  NoteState stateOf(HmmNote n) =>
      statesByUuid[n.uuid] ?? NoteState.none(n.uuid);

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

  /// Active tag id -> name, so a token for a deleted tag can be told apart
  /// from a live tag no note carries. Null means unknown: every tag is live.
  final Map<int, String>? liveTagNames;

  /// Per-catalog counts, for the filter sheet's individual catalog rows.
  /// A note attached to something in another domain no longer tallies under
  /// its own catalog here (it filters under that domain instead, so counting it here would show a catalog whose filter
  /// returns nothing); use [countsByDomain] for domain-level aggregates.
  Map<int, int> get countsByCatalog {
    final m = <int, int>{};
    for (final n in all) {
      final c = n.catalogId;
      if (c == null) continue;
      final parent = parentDomainOf(n);
      if (parent != null && parent != ownDomainOf(n)) continue;
      m[c] = (m[c] ?? 0) + 1;
    }
    return m;
  }

  /// Per-domain counts, agreeing with what selecting a whole domain shows when a whole
  /// domain is selected: each note counts under [effectiveDomain], not its
  /// own catalog's domain. Drives the filter sheet's domain subtitle and the
  /// drawer's sort order, so a domain's displayed count never disagrees with
  /// what tapping it actually shows.
  Map<String, int> get countsByDomain {
    final m = <String, int>{};
    for (final n in all) {
      final d = effectiveDomain(n);
      if (d != null) m[d] = (m[d] ?? 0) + 1;
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

  NotesListData copyWith({
    List<HmmNote>? all,
    Map<int, NoteCatalog>? catalogsById,
    Map<String, NoteState>? statesByUuid,
    Map<int, List<NoteTagLabel>>? tagsByNoteId,
    NoteQuery? query,
    Map<int, String>? catalogDomainById,
    Map<int, String>? anchorDomainById,
    Map<int, AttachTarget>? targetsById,
    Map<int, String>? liveTagNames,
  }) {
    return NotesListData(
      all: all ?? this.all,
      catalogsById: catalogsById ?? this.catalogsById,
      statesByUuid: statesByUuid ?? this.statesByUuid,
      tagsByNoteId: tagsByNoteId ?? this.tagsByNoteId,
      query: query ?? this.query,
      catalogDomainById: catalogDomainById ?? this.catalogDomainById,
      anchorDomainById: anchorDomainById ?? this.anchorDomainById,
      targetsById: targetsById ?? this.targetsById,
      liveTagNames: liveTagNames ?? this.liveTagNames,
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
final _catalogsStreamProvider = StreamProvider.autoDispose<List<NoteCatalog>>((
  ref,
) {
  return ref.watch(noteCatalogRepositoryProvider).watchCatalogs();
});

final _statesStreamProvider =
    StreamProvider.autoDispose<Map<String, NoteState>>((ref) {
      return ref.watch(noteStateRepositoryProvider).watchAllStates();
    });

final _noteTagsStreamProvider =
    StreamProvider.autoDispose<Map<int, List<NoteTagLabel>>>((ref) {
      return ref.watch(tagRepositoryProvider).watchNoteTags();
    });

final _liveTagNamesStreamProvider =
    StreamProvider.autoDispose<Map<int, String>>((ref) {
      return ref.watch(tagRepositoryProvider).watchLiveTagNames();
    });

class NotesListState extends AsyncNotifier<NotesListData> {
  // View criteria live on the notifier so they survive reactive data
  // emissions (which refresh the data, not the user's filter/sort/search).
  NoteQuery _query = const NoteQuery.initial();

  @override
  Future<NotesListData> build() async {
    final notes = await ref.watch(_notesStreamProvider.future);
    final catalogs = await ref.watch(_catalogsStreamProvider.future);
    final states = await ref.watch(_statesStreamProvider.future);
    final tags = await ref.watch(_noteTagsStreamProvider.future);
    final liveTagNames = await ref.watch(_liveTagNamesStreamProvider.future);
    final anchorMatches = catalogs.where(
      (c) => c.name == kSubsystemAnchorCatalogName,
    );
    final anchorCatalogId = anchorMatches.isEmpty
        ? null
        : anchorMatches.first.id;
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
          n.id: (domain: catalogDomainById[n.catalogId]!, subject: n.subject),
    };

    return NotesListData(
      all: visibleNotes,
      catalogsById: byId,
      statesByUuid: states,
      tagsByNoteId: tags,
      query: _query,
      catalogDomainById: catalogDomainById,
      anchorDomainById: anchorDomainById,
      targetsById: targetsById,
      liveTagNames: liveTagNames,
    );
  }

  void setQuery(NoteQuery query) {
    _query = query;
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(query: query));
  }

  void setText(String text) => setQuery(_query.copyWith(text: text));

  void setTokens(List<NoteToken> tokens) =>
      setQuery(_query.copyWith(tokens: tokens));

  void setScope(NoteScope scope) => setQuery(_query.copyWith(scope: scope));

  void setSort(NoteSort sort) => setQuery(_query.copyWith(sort: sort));

  void setSource(NoteSource source) =>
      setQuery(_query.copyWith(source: source));

  /// Pull-to-refresh hook. The list already updates reactively, so this just
  /// re-subscribes the underlying streams; harmless if invoked.
  Future<void> refresh() async {
    ref.invalidate(_notesStreamProvider);
    ref.invalidate(_catalogsStreamProvider);
    ref.invalidate(_statesStreamProvider);
    ref.invalidate(_noteTagsStreamProvider);
    ref.invalidate(_liveTagNamesStreamProvider);
  }
}

final notesListStateProvider =
    AsyncNotifierProvider<NotesListState, NotesListData>(
      () => NotesListState(),
    );
