import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../calendar/states/remind_on_device_provider.dart';
import '../../notes/presentation/widgets/video_tile.dart'
    show kInlineVideoMinShortestSide;
import '../../settings/data/syncable_settings_repository.dart';
import '../../settings/providers/settings_bus_provider.dart';
import '../domain/glucose_range.dart';
import '../domain/glucose_units.dart';

/// Target range. Synced (three [SyncableSettings] fields stored together):
/// null until all of low, high and a parsable unit are present.
class GlucoseRangeNotifier extends Notifier<GlucoseRange?> {
  // A set()/clear() that lands before hydration must not be overwritten by
  // the stale prefs read.
  int _writes = 0;

  @override
  GlucoseRange? build() {
    ref.watch(settingsBusProvider);
    _writes = 0;
    _load();
    return null;
  }

  Future<void> _load() async {
    final writesAtStart = _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || _writes != writesAtStart) return;
      final low = prefs.getDouble(
        SyncableSettingsRepository.glucoseRangeLowKey,
      );
      final high = prefs.getDouble(
        SyncableSettingsRepository.glucoseRangeHighKey,
      );
      final rawUnit = prefs.getString(
        SyncableSettingsRepository.glucoseRangeUnitKey,
      );
      final unit = rawUnit == null ? null : GlucoseUnit.fromWire(rawUnit);
      state = (low != null && high != null && unit != null)
          ? GlucoseRange(low: low, high: high, unit: unit)
          : null;
    } catch (e) {
      debugPrint('GlucoseRange: setting unreadable (${e.runtimeType})');
    }
  }

  Future<void> set(GlucoseRange range) async {
    _writes++;
    state = range;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      SyncableSettingsRepository.glucoseRangeLowKey,
      range.low.toDouble(),
    );
    await prefs.setDouble(
      SyncableSettingsRepository.glucoseRangeHighKey,
      range.high.toDouble(),
    );
    await prefs.setString(
      SyncableSettingsRepository.glucoseRangeUnitKey,
      range.unit.wire,
    );
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }

  Future<void> clear() async {
    _writes++;
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SyncableSettingsRepository.glucoseRangeLowKey);
    await prefs.remove(SyncableSettingsRepository.glucoseRangeHighKey);
    await prefs.remove(SyncableSettingsRepository.glucoseRangeUnitKey);
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final glucoseRangeProvider =
    NotifierProvider<GlucoseRangeNotifier, GlucoseRange?>(
      GlucoseRangeNotifier.new,
    );

/// Display unit. Synced. Unset → mg/dL when the device region is US, else
/// mmol/L. [regionCountry] fixes the region (tests); otherwise the platform
/// locale is asked.
class GlucoseDisplayUnitNotifier extends Notifier<GlucoseUnit> {
  GlucoseDisplayUnitNotifier({String? regionCountry})
    : _regionCountry = regionCountry;

  final String? _regionCountry;
  int _writes = 0;

  GlucoseUnit get _default {
    final country =
        _regionCountry ?? PlatformDispatcher.instance.locale.countryCode;
    return country == 'US' ? GlucoseUnit.mgdl : GlucoseUnit.mmoll;
  }

  @override
  GlucoseUnit build() {
    ref.watch(settingsBusProvider);
    _writes = 0;
    _load();
    return _default;
  }

  Future<void> _load() async {
    final writesAtStart = _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || _writes != writesAtStart) return;
      final raw = prefs.getString(
        SyncableSettingsRepository.glucoseDisplayUnitKey,
      );
      state = (raw == null ? null : GlucoseUnit.fromWire(raw)) ?? _default;
    } catch (e) {
      debugPrint('GlucoseDisplayUnit: setting unreadable (${e.runtimeType})');
    }
  }

  Future<void> set(GlucoseUnit unit) async {
    _writes++;
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SyncableSettingsRepository.glucoseDisplayUnitKey,
      unit.wire,
    );
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final glucoseDisplayUnitProvider =
    NotifierProvider<GlucoseDisplayUnitNotifier, GlucoseUnit>(
      GlucoseDisplayUnitNotifier.new,
    );

/// "Import from Apple Health on this device": per device, never synced.
/// Unset → on for a phone (shortest side < 600 pt), off for a tablet or an
/// unknown size. Same shape as [RemindOnDeviceNotifier].
class GlucoseImportOnDeviceNotifier extends Notifier<bool> {
  static const prefsKey = 'glucose.importOnDevice';

  /// Completes once the stored value (if any) has been applied.
  late Future<void> loaded;
  bool? _userValue;

  @override
  bool build() {
    final side = ref.watch(deviceShortestSideProvider);
    final byDefault = side != null && side < kInlineVideoMinShortestSide;
    loaded = _load();
    return _userValue ?? byDefault;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || _userValue != null) return;
    final stored = prefs.getBool(prefsKey);
    if (stored != null) state = stored;
  }

  Future<void> set(bool value) async {
    _userValue = value;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }
}

final glucoseImportOnDeviceProvider =
    NotifierProvider<GlucoseImportOnDeviceNotifier, bool>(
      GlucoseImportOnDeviceNotifier.new,
    );

/// Per-device import bookkeeping: whether a first import ran, and the end of
/// the last import window.
class GlucoseImportPrefs {
  static const importedOnceKey = 'glucose.importedOnce';
  static const lastImportEndKey = 'glucose.lastImportEnd';

  Future<bool> importedOnce() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(importedOnceKey) ?? false;
  }

  Future<void> markImportedOnce() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(importedOnceKey, true);
  }

  Future<DateTime?> lastImportEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastImportEndKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> setLastImportEnd(DateTime utc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastImportEndKey, utc.toUtc().toIso8601String());
  }
}

final glucoseImportPrefsProvider = Provider<GlucoseImportPrefs>(
  (ref) => GlucoseImportPrefs(),
);
