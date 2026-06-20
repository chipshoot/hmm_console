import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in toggle: "Add location to new notes". Default false. Device-local
/// (not synced). AsyncNotifier so the editor can `await .future` and reliably
/// read the persisted value before deciding to capture.
class GeoCaptureNotifier extends AsyncNotifier<bool> {
  static const _key = 'geo_capture_enabled';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = AsyncData(value);
  }
}

final geoCaptureEnabledProvider =
    AsyncNotifierProvider<GeoCaptureNotifier, bool>(GeoCaptureNotifier.new);
