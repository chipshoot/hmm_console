import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';

/// Opt-in toggle: "Add location to new notes". Default false. Device-local
/// (not synced). AsyncNotifier so the editor can `await .future` and reliably
/// read the persisted value before deciding to capture. Value + persistence
/// live in the unified SettingsController.
class GeoCaptureNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      (await ref.watch(settingsProvider.future)).geoCaptureEnabled;

  Future<void> setEnabled(bool value) =>
      ref.read(settingsProvider.notifier).setGeoCaptureEnabled(value);
}

final geoCaptureEnabledProvider =
    AsyncNotifierProvider<GeoCaptureNotifier, bool>(GeoCaptureNotifier.new);
