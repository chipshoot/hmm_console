import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _recentsKey = 'launcher_recents';
const _cap = 8;

/// Most-recently-launched destination ids, newest first, capped at
/// [_cap]. Device-local (NOT synced) — recents are personal to the
/// device, like a phone's app-switcher.
class LauncherRecentsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final raw = prefs.getString(_recentsKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).whereType<String>().toList();
      state = list;
    }
  }

  Future<void> record(String id) async {
    final next = [id, ...state.where((x) => x != id)].take(_cap).toList();
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentsKey, jsonEncode(next));
  }
}

final launcherRecentsProvider =
    NotifierProvider<LauncherRecentsNotifier, List<String>>(
  () => LauncherRecentsNotifier(),
);
