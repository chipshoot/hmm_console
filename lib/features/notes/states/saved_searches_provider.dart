import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/util/uuid.dart';
import '../../settings/data/syncable_settings_repository.dart';
import '../../settings/providers/settings_bus_provider.dart';
import '../query/note_query.dart';
import '../query/saved_search.dart';

/// The user's saved searches, sorted by `order`. Same shape as
/// `ContactSortByNotifier`: a synchronous `[]`, hydrated from prefs, and
/// re-read when a pulled settings bundle bumps the bus.
class SavedSearchesNotifier extends Notifier<List<SavedSearch>> {
  /// The last list published; the notifier instance outlives rebuilds.
  List<SavedSearch> _shown = const [];

  @override
  List<SavedSearch> build() {
    ref.watch(settingsBusProvider);
    _hydrate();
    // Keep what is shown while a rebuild re-reads, so an open saved search
    // does not flash as deleted.
    return _shown;
  }

  Future<List<SavedSearch>> _readPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      SyncableSettingsRepository.notesSavedSearchesKey,
    );
    if (raw == null) return const [];
    try {
      return _sorted(parseSavedSearches(jsonDecode(raw)));
    } catch (e) {
      // Type only: the saved searches are user content.
      debugPrint('SavedSearches: unreadable (${e.runtimeType})');
      return const [];
    }
  }

  Future<void> _hydrate() async {
    final list = await _readPrefs();
    if (!ref.mounted) return;
    _shown = list;
    state = list;
  }

  List<SavedSearch> _sorted(List<SavedSearch> l) =>
      [...l]..sort((a, b) => a.order.compareTo(b.order));

  /// Renumbers to 0..n-1, publishes, persists and bumps the settings stamp.
  Future<void> _commit(List<SavedSearch> list) async {
    final renumbered = [
      for (var i = 0; i < list.length; i++)
        list[i].order == i ? list[i] : list[i].copyWith(order: i),
    ];
    _shown = renumbered;
    state = renumbered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SyncableSettingsRepository.notesSavedSearchesKey,
      jsonEncode([for (final s in renumbered) s.toJson()]),
    );
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }

  Future<SavedSearch> add(String name, NoteQuery query) async {
    final list = await _readPrefs();
    final s = SavedSearch(
      id: generateUuid(),
      name: name,
      order: list.length,
      query: query,
    );
    await _commit([...list, s]);
    return s;
  }

  Future<void> rename(String id, String name) async {
    final list = await _readPrefs();
    await _commit([
      for (final s in list) s.id == id ? s.copyWith(name: name) : s,
    ]);
  }

  /// [delta] is -1 (up) or +1 (down); clamps at the ends.
  Future<void> move(String id, int delta) async {
    final list = await _readPrefs();
    final from = list.indexWhere((s) => s.id == id);
    if (from < 0) return;
    final to = (from + delta).clamp(0, list.length - 1);
    if (to == from) return;
    final item = list.removeAt(from);
    list.insert(to, item);
    await _commit(list);
  }

  Future<void> remove(String id) async {
    final list = await _readPrefs();
    await _commit([
      for (final s in list)
        if (s.id != id) s,
    ]);
  }

  /// Reinserts [s] at its former `order` (clamped), e.g. to undo a remove.
  Future<void> restore(SavedSearch s) async {
    final list = (await _readPrefs()).where((x) => x.id != s.id).toList();
    list.insert(s.order.clamp(0, list.length), s);
    await _commit(list);
  }
}

final savedSearchesProvider =
    NotifierProvider<SavedSearchesNotifier, List<SavedSearch>>(
      SavedSearchesNotifier.new,
    );
