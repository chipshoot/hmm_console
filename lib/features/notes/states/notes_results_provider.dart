import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../contacts/domain/pinyin_transcriber.dart';
import '../../contacts/states/pinyin_transcriber_provider.dart';
import '../data/models/hmm_note.dart';
import '../query/markdown_text.dart';
import '../query/note_index_warmer.dart';
import '../query/note_query_engine.dart';
import '../query/note_results.dart';
import '../query/note_text_index.dart';
import '../query/note_query.dart';
import '../query/smart_query.dart';
import '../rendering/note_display.dart';
import 'notes_list_state.dart';
import 'saved_searches_provider.dart';

/// Keep-alive: the folded text of every note, shared by all evaluations.
final noteTextIndexCacheProvider = Provider<NoteTextIndexCache>(
  (ref) => NoteTextIndexCache(),
);

/// What the results depend on besides the notes: known only to the widget
/// tree (locale, first day of week).
typedef NotesViewEnv = ({Locale locale, int firstDayOfWeek});

class NotesViewEnvNotifier extends Notifier<NotesViewEnv?> {
  @override
  NotesViewEnv? build() => null;

  void set(NotesViewEnv env) {
    if (state != env) state = env;
  }
}

final notesViewEnvProvider =
    NotifierProvider<NotesViewEnvNotifier, NotesViewEnv?>(
      NotesViewEnvNotifier.new,
    );

class NotesIndexRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Bumped as the warmer makes progress (throttled), so a search in flight
/// re-evaluates. Watched only while searching: without search text the
/// results do not read the index.
final notesIndexRevisionProvider =
    NotifierProvider<NotesIndexRevisionNotifier, int>(
      NotesIndexRevisionNotifier.new,
    );

/// The indexing the warmer currently builds with; replaced per corpus.
class _IndexingHolder {
  NoteIndexing? current;

  /// Built with [current]; reused with it, so its per-corpus memo (counts)
  /// survives query edits.
  InMemoryNoteQueryEngine? engine;
  NotesListData? warmedData;
  NotesViewEnv? warmedEnv;
}

final _indexingHolderProvider = Provider<_IndexingHolder>(
  (ref) => _IndexingHolder(),
);

final _noteIndexWarmerProvider = Provider<NoteIndexWarmer>((ref) {
  final holder = ref.watch(_indexingHolderProvider);
  final warmer = NoteIndexWarmer(
    cache: ref.watch(noteTextIndexCacheProvider),
    keyOf: (n) => holder.current!.keyOf(n),
    build: (n) => holder.current!.build(n),
    onProgress: () => ref.read(notesIndexRevisionProvider.notifier).bump(),
  );
  ref.onDispose(warmer.cancel);
  return warmer;
});

/// Per-corpus keys, titles and index entries for the notes list. Memoized,
/// so the engine's repeated key lookups cost a map read.
class NoteIndexing {
  NoteIndexing({
    required this.corpus,
    required this.registry,
    required this.l,
    required this.localeTag,
    required this.pinyin,
  });

  final NotesListData corpus;
  final NoteDisplayRegistry registry;
  final AppLocalizations l;
  final String localeTag;
  final PinyinTranscriber pinyin;

  late final Map<int, HmmNote> _byId = {for (final n in corpus.all) n.id: n};
  final _titles = <int, String>{};
  final _keys = <int, NoteTextKey>{};

  String? _catalogName(HmmNote n) => corpus.catalogsById[n.catalogId]?.name;

  String title(HmmNote n) =>
      _titles[n.id] ??= registry.title(n, _catalogName(n), l);

  String _parentTitle(HmmNote n) {
    final p = n.parentNoteId;
    if (p == null) return '';
    final parent = _byId[p];
    if (parent != null) return title(parent);
    return corpus.contextSubjectOf(n) ?? '';
  }

  List<String> _tagNames(HmmNote n) =>
      [for (final t in corpus.tagsByNoteId[n.id] ?? const []) t.name]..sort();

  NoteTextKey keyOf(HmmNote n) => _keys[n.id] ??= (
    noteId: n.id,
    version: _version(n),
    locale: localeTag,
    parentTitle: _parentTitle(n),
    tags: _tagNames(n).join('\u0001'),
  );

  static String _version(HmmNote n) {
    final v = n.version;
    if (v != null) {
      return v.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
    return n.lastModifiedDate?.toIso8601String() ?? '';
  }

  /// Plain markdown text, or the entity note's own preview (never raw JSON).
  NoteTextIndex build(HmmNote n) {
    final catalog = _catalogName(n);
    final body = registry.hasEntry(catalog)
        ? registry.noteDisplay(n, catalog, l).preview
        : markdownToPlainText(n.content ?? '');
    return buildNoteTextIndex(
      title: title(n),
      body: body,
      parentTitle: _parentTitle(n),
      tagNames: _tagNames(n),
      pinyin: pinyin,
    );
  }
}

bool _sameCorpus(NotesListData? a, NotesListData b) =>
    a != null &&
    identical(a.all, b.all) &&
    identical(a.tagsByNoteId, b.tagsByNoteId) &&
    identical(a.targetsById, b.targetsById) &&
    identical(a.catalogsById, b.catalogsById);

NoteIndexing _indexingFor(Ref ref, NotesListData data, NotesViewEnv env) =>
    NoteIndexing(
      corpus: data,
      registry: ref.read(noteDisplayRegistryProvider),
      l: lookupAppLocalizations(env.locale),
      localeTag: env.locale.toLanguageTag(),
      pinyin: ref.read(pinyinTranscriberProvider),
    );

/// The live query with a saved-search source expanded; null while the list
/// is loading.
final notesEffectiveQueryProvider = Provider.autoDispose<NoteQuery?>((ref) {
  final live = ref.watch(notesListStateProvider).value?.query;
  if (live == null) return null;
  return resolveSmartQuery(live, ref.watch(notesSmartFiltersProvider));
});

/// The single feed the list screen reads. Loading until the list data and
/// the view env are both known.
final notesResultsProvider = Provider.autoDispose<AsyncValue<NoteResults>>((
  ref,
) {
  final env = ref.watch(notesViewEnvProvider);
  final listAsync = ref.watch(notesListStateProvider);
  final cache = ref.watch(noteTextIndexCacheProvider);

  final data = listAsync.value;
  final query = ref.watch(notesEffectiveQueryProvider);
  if (env == null || data == null || query == null) {
    final error = listAsync.error;
    if (env != null && error != null) {
      return AsyncError(error, listAsync.stackTrace ?? StackTrace.empty);
    }
    return const AsyncLoading();
  }

  if (query.text.trim().isNotEmpty) ref.watch(notesIndexRevisionProvider);

  // One indexing per corpus + env: query edits reuse it (and its memoized
  // keys and titles); a new corpus or env builds a new one and re-warms. The
  // warmer yields before its first slice, so this never writes mid-build.
  final holder = ref.read(_indexingHolderProvider);
  var indexing = holder.current;
  if (indexing == null ||
      holder.warmedEnv != env ||
      !_sameCorpus(holder.warmedData, data)) {
    indexing = _indexingFor(ref, data, env);
    holder.warmedData = data;
    holder.warmedEnv = env;
    holder.current = indexing;
    holder.engine = InMemoryNoteQueryEngine(
      cache: cache,
      keyOf: indexing.keyOf,
      titleOf: indexing.title,
      pinyin: ref.read(pinyinTranscriberProvider),
    );
    ref.read(_noteIndexWarmerProvider).warm(data.all);
  }
  final engine = holder.engine!;
  return AsyncData(
    engine.evaluate(
      query,
      data,
      now: DateTime.now(),
      firstDayOfWeek: env.firstDayOfWeek,
    ),
  );
});
