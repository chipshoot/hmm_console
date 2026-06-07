import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks how often the user filters the notes list by each domain, persisted
/// across launches. Drives the order of the inline quick-filter chips so the
/// most-used domains float to the front.
///
/// State is `domainKey -> tap count`. Empty until the user filters; callers
/// fall back to a sensible default order (e.g. note count) while it's empty.
class FilterUsageNotifier extends AsyncNotifier<Map<String, int>> {
  static const _prefsKey = 'notes.filter_usage';

  @override
  Future<Map<String, int>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// Increment the usage count for [domainKey] and persist.
  Future<void> record(String domainKey) async {
    final current = Map<String, int>.from(state.value ?? const {});
    current[domainKey] = (current[domainKey] ?? 0) + 1;
    state = AsyncData(current);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(current));
  }
}

final filterUsageProvider =
    AsyncNotifierProvider<FilterUsageNotifier, Map<String, int>>(
  FilterUsageNotifier.new,
);
