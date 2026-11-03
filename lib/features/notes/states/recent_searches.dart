import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';
import '../query/note_query.dart';

/// A remembered search: the free text plus its tokens.
typedef RecentSearch = ({String text, List<NoteToken> tokens});

const int kMaxRecentSearches = 10;

bool _same(RecentSearch a, RecentSearch b) =>
    a.text == b.text && listEquals(a.tokens, b.tokens);

/// Returns [list] with [r] (text trimmed) moved to the front. An entry with
/// neither text nor tokens is ignored; the list is capped at
/// [kMaxRecentSearches], newest first.
List<RecentSearch> pushRecent(List<RecentSearch> list, RecentSearch r) {
  final entry = (text: r.text.trim(), tokens: r.tokens);
  if (entry.text.isEmpty && entry.tokens.isEmpty) return list;
  return [
    entry,
    for (final e in list)
      if (!_same(e, entry)) e,
  ].take(kMaxRecentSearches).toList();
}

RecentSearch _decode(Map<String, Object?> m) {
  final text = m['text'];
  final tokens = m['tokens'];
  return (
    text: text is String ? text : '',
    tokens: [
      if (tokens is List)
        for (final t in tokens) NoteToken.fromJson(t),
    ],
  );
}

Map<String, Object?> _encode(RecentSearch r) => {
  'text': r.text,
  'tokens': [for (final t in r.tokens) t.toJson()],
};

/// Per-device recent searches, persisted in the unified SettingsController.
class RecentSearchesNotifier extends AsyncNotifier<List<RecentSearch>> {
  @override
  Future<List<RecentSearch>> build() async => [
    for (final m in (await ref.watch(
      settingsProvider.future,
    )).notesRecentSearches)
      _decode(m),
  ];

  /// Reads the controller (the source of truth) rather than derived state so
  /// rapid consecutive records don't race on a stale copy.
  Future<void> record(NoteQuery q) async {
    final settings = await ref.read(settingsProvider.future);
    final next = pushRecent(
      [for (final m in settings.notesRecentSearches) _decode(m)],
      (text: q.text, tokens: q.tokens),
    );
    await ref.read(settingsProvider.notifier).setNotesRecentSearches([
      for (final r in next) _encode(r),
    ]);
  }

  Future<void> clear() =>
      ref.read(settingsProvider.notifier).setNotesRecentSearches(const []);
}

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<RecentSearch>>(
      RecentSearchesNotifier.new,
    );
