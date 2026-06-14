import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local/database.dart';
import '../../../core/data/repository_providers.dart';
import '../data/models/hmm_note.dart';
import '../data/subsystem_anchor.dart';

enum NoteSort { dateNewest, dateOldest, lastModified, subjectAZ }

const Object _unset = Object();

class NotesListData {
  const NotesListData({
    required this.all,
    required this.catalogsById,
    this.catalogFilter,
    this.sort = NoteSort.dateNewest,
    this.query = '',
  });

  final List<HmmNote> all;
  final Map<int, NoteCatalog> catalogsById;
  final Set<int>? catalogFilter; // null = all
  final NoteSort sort;
  final String query;

  Map<int, int> get countsByCatalog {
    final m = <int, int>{};
    for (final n in all) {
      final c = n.catalogId;
      if (c != null) m[c] = (m[c] ?? 0) + 1;
    }
    return m;
  }

  List<HmmNote> get visible {
    Iterable<HmmNote> items = all;
    final f = catalogFilter;
    if (f != null && f.isNotEmpty) {
      items = items.where((n) => n.catalogId != null && f.contains(n.catalogId));
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((n) => n.subject.toLowerCase().contains(q));
    }
    final list = items.toList();
    switch (sort) {
      case NoteSort.dateNewest:
        list.sort((a, b) => b.createDate.compareTo(a.createDate));
      case NoteSort.dateOldest:
        list.sort((a, b) => a.createDate.compareTo(b.createDate));
      case NoteSort.lastModified:
        list.sort((a, b) => (b.lastModifiedDate ?? b.createDate)
            .compareTo(a.lastModifiedDate ?? a.createDate));
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
  }) {
    return NotesListData(
      all: all ?? this.all,
      catalogsById: catalogsById ?? this.catalogsById,
      catalogFilter: identical(catalogFilter, _unset)
          ? this.catalogFilter
          : catalogFilter as Set<int>?,
      sort: sort ?? this.sort,
      query: query ?? this.query,
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
    final byId = {for (final c in catalogs) c.id: c};
    final anchorMatches =
        catalogs.where((c) => c.name == kSubsystemAnchorCatalogName);
    final anchorCatalogId =
        anchorMatches.isEmpty ? null : anchorMatches.first.id;
    final visibleNotes = anchorCatalogId == null
        ? notes
        : notes.where((n) => n.catalogId != anchorCatalogId).toList();
    return NotesListData(
      all: visibleNotes,
      catalogsById: byId,
      catalogFilter: _filter,
      sort: _sort,
      query: _query,
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
