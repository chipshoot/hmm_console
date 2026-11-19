// lib/features/calendar/states/holiday_settings_providers.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/syncable_settings_repository.dart';
import '../../settings/providers/settings_bus_provider.dart';
import '../domain/holidays.dart';

/// Subscribed holiday regions. Synced. Defaults to [kDefaultHolidayRegions]
/// until the owner edits (nothing is written before that).
class HolidayRegionsNotifier extends Notifier<List<HolidayRegion>> {
  // A write that lands before hydration finishes must not be overwritten by
  // the stale prefs read.
  int _writes = 0;
  final _hydrated = Completer<void>();
  List<HolidayRegion>? _shown;

  void _set(List<HolidayRegion> value) => state = _shown = value;

  /// Completes once the stored list was first read (or an edit superseded
  /// it). Until then the state is only the default list.
  Future<void> get hydrated => _hydrated.future;
  bool get isHydrated => _hydrated.isCompleted;

  @override
  List<HolidayRegion> build() {
    ref.watch(settingsBusProvider);
    _writes = 0;
    _load();
    // A settings pull re-runs build: keep what is shown while prefs are
    // re-read, so nothing flashes back to the defaults. (`stateOrNull` is
    // null during a rebuild, so the notifier keeps its own copy.)
    return _shown ?? kDefaultHolidayRegions;
  }

  Future<void> _load() async {
    final writesAtStart = _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      // A newer build's load takes over (and completes hydration).
      if (!ref.mounted) return;
      if (_writes != writesAtStart) return _markHydrated();
      final raw = prefs.getString(
        SyncableSettingsRepository.calendarHolidayRegionsKey,
      );
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _set([for (final r in decoded) ?HolidayRegion.fromJson(r)]);
        }
      }
    } catch (e) {
      debugPrint('HolidayRegions: setting unreadable (${e.runtimeType})');
    }
    _markHydrated();
  }

  void _markHydrated() {
    if (!_hydrated.isCompleted) _hydrated.complete();
  }

  Future<void> _write(List<HolidayRegion> value) async {
    _writes++;
    _set(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SyncableSettingsRepository.calendarHolidayRegionsKey,
      jsonEncode([for (final r in value) r.toJson()]),
    );
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }

  /// False when that country + region is already subscribed.
  Future<bool> add(String country, String? region) async {
    final current = state;
    if (current.any((r) => r.country == country && r.region == region)) {
      return false;
    }
    final used = {for (final r in current) r.color};
    var color = 0;
    for (var i = 0; i < kHolidayPalette.length; i++) {
      if (!used.contains(i)) {
        color = i;
        break;
      }
    }
    await _write([
      ...current,
      HolidayRegion(country: country, region: region, color: color),
    ]);
    return true;
  }

  Future<void> remove(String sourceId) => _write([
    for (final r in state)
      if (r.sourceId != sourceId) r,
  ]);

  Future<void> restore(List<HolidayRegion> previous) => _write(previous);
}

final holidayRegionsProvider =
    NotifierProvider<HolidayRegionsNotifier, List<HolidayRegion>>(
      HolidayRegionsNotifier.new,
    );

/// The user's own holidays plus hidden downloaded ones. Synced.
class MyHolidaysNotifier extends Notifier<MyHolidaysData> {
  int _writes = 0;
  final _hydrated = Completer<void>();
  MyHolidaysData? _shown;

  void _set(MyHolidaysData value) => state = _shown = value;

  /// Completes once the stored data was first read (or an edit superseded
  /// it). Until then the state is only the empty default.
  Future<void> get hydrated => _hydrated.future;
  bool get isHydrated => _hydrated.isCompleted;

  @override
  MyHolidaysData build() {
    ref.watch(settingsBusProvider);
    _writes = 0;
    _load();
    return _shown ?? MyHolidaysData.empty;
  }

  Future<void> _load() async {
    final writesAtStart = _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      // A newer build's load takes over (and completes hydration).
      if (!ref.mounted) return;
      if (_writes != writesAtStart) return _markHydrated();
      final raw = prefs.getString(
        SyncableSettingsRepository.calendarMyHolidaysKey,
      );
      if (raw != null) _set(MyHolidaysData.fromJson(jsonDecode(raw)));
    } catch (e) {
      debugPrint('MyHolidays: setting unreadable (${e.runtimeType})');
    }
    _markHydrated();
  }

  void _markHydrated() {
    if (!_hydrated.isCompleted) _hydrated.complete();
  }

  Future<void> _write(MyHolidaysData value) async {
    _writes++;
    _set(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SyncableSettingsRepository.calendarMyHolidaysKey,
      jsonEncode(value.toJson()),
    );
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }

  Future<void> upsert(MyHoliday holiday) {
    final entries = [...state.entries];
    final i = entries.indexWhere((e) => e.id == holiday.id);
    if (i >= 0) {
      entries[i] = holiday;
    } else {
      entries.add(holiday);
    }
    return _write(MyHolidaysData(entries: entries, hidden: state.hidden));
  }

  Future<void> delete(String id) => _write(
    MyHolidaysData(
      entries: [
        for (final e in state.entries)
          if (e.id != id) e,
      ],
      hidden: state.hidden,
    ),
  );

  Future<void> hide(String source, String name) {
    final h = HiddenHoliday(source: source, name: name);
    if (state.hidden.contains(h)) return Future.value();
    return _write(
      MyHolidaysData(entries: state.entries, hidden: [...state.hidden, h]),
    );
  }

  Future<void> unhide(String source, String name) {
    final h = HiddenHoliday(source: source, name: name);
    if (!state.hidden.contains(h)) return Future.value();
    return _write(
      MyHolidaysData(
        entries: state.entries,
        hidden: [
          for (final x in state.hidden)
            if (x != h) x,
        ],
      ),
    );
  }

  Future<void> restore(MyHolidaysData previous) => _write(previous);
}

final myHolidaysProvider = NotifierProvider<MyHolidaysNotifier, MyHolidaysData>(
  MyHolidaysNotifier.new,
);
