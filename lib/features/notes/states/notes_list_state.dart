import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local/database.dart';
import '../../../core/data/repository_providers.dart';
import '../data/models/hmm_note.dart';

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

class NotesListState extends AsyncNotifier<NotesListData> {
  Future<NotesListData> _load() async {
    final page =
        await ref.read(hmmNoteRepositoryProvider).getNotes(pageSize: 500);
    final catalogs =
        await ref.read(noteCatalogRepositoryProvider).getCatalogs();
    return NotesListData(
      all: page.items,
      catalogsById: {for (final c in catalogs) c.id: c},
    );
  }

  @override
  Future<NotesListData> build() => _load();

  void setSort(NoteSort sort) {
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(sort: sort));
  }

  void setQuery(String query) {
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(query: query));
  }

  void setFilter(Set<int>? catalogIds) {
    final v = state.value;
    if (v != null) state = AsyncData(v.copyWith(catalogFilter: catalogIds));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}

final notesListStateProvider =
    AsyncNotifierProvider<NotesListState, NotesListData>(
  () => NotesListState(),
);
