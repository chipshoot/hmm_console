import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';

/// Tracks how often the user filters the notes list by each domain, persisted
/// across launches. Drives the order of the inline quick-filter chips so the
/// most-used domains float to the front.
///
/// State is `domainKey -> tap count`. Value + persistence live in the unified
/// SettingsController.
class FilterUsageNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async =>
      (await ref.watch(settingsProvider.future)).notesFilterUsage;

  /// Increment the usage count for [domainKey] and persist. Reads the current
  /// value from the controller (the source of truth) rather than this
  /// notifier's derived state, so rapid consecutive records don't race on a
  /// stale copy.
  Future<void> record(String domainKey) async {
    final settings = await ref.read(settingsProvider.future);
    final current = Map<String, int>.from(settings.notesFilterUsage);
    current[domainKey] = (current[domainKey] ?? 0) + 1;
    await ref.read(settingsProvider.notifier).setNotesFilterUsage(current);
  }
}

final filterUsageProvider =
    AsyncNotifierProvider<FilterUsageNotifier, Map<String, int>>(
  FilterUsageNotifier.new,
);
