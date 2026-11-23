// lib/features/settings/providers/home_hidden_tiles_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard/domain/home_tiles.dart';
import '../data/syncable_settings_repository.dart';
import 'settings_bus_provider.dart';

/// Ids of home-screen tiles the user hid. Same shape as
/// `ContactSortByNotifier`: a synchronous default (nothing hidden), hydrated
/// from prefs, re-read when a pulled settings bundle bumps the bus.
///
/// Unknown ids (a tile from a newer build) are ignored by the dashboard but
/// kept in the set so they survive a round trip. At least one known tile always
/// stays visible.
class HomeHiddenTilesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(settingsBusProvider);
    _load();
    return const <String>{};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state =
          (prefs.getStringList(SyncableSettingsRepository.homeHiddenTilesKey) ??
                  const <String>[])
              .toSet();
    } catch (e) {
      // Type only. The home screen keeps showing every tile.
      debugPrint('HomeHiddenTiles: setting unreadable (${e.runtimeType})');
    }
  }

  /// Shows or hides tile [id]. Hiding the last visible tile is refused.
  Future<void> setVisible(String id, bool visible) async {
    final next = {...state};
    if (visible) {
      next.remove(id);
    } else {
      next.add(id);
      final anyVisible = homeTiles.any((t) => !next.contains(t.route));
      if (!anyVisible) return;
    }
    if (next.length == state.length && next.containsAll(state)) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      SyncableSettingsRepository.homeHiddenTilesKey,
      next.toList()..sort(),
    );
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final homeHiddenTilesProvider =
    NotifierProvider<HomeHiddenTilesNotifier, Set<String>>(
      HomeHiddenTilesNotifier.new,
    );
