import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../notes/presentation/widgets/video_tile.dart'
    show kInlineVideoMinShortestSide;

/// Shortest side of this device's screen in logical points. The app root
/// overrides it with [platformShortestSide] read once at startup; tests set
/// it directly.
final deviceShortestSideProvider = Provider<double>(
  (ref) => platformShortestSide(),
);

/// Shortest side of the first view's display (the physical screen, so an
/// iPad in Split View still counts as a tablet), in logical points.
double platformShortestSide() {
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return 0;
  final view = views.first;
  try {
    final d = view.display;
    return d.size.shortestSide / d.devicePixelRatio;
  } catch (_) {
    return view.physicalSize.shortestSide / view.devicePixelRatio;
  }
}

/// "Remind on this device": per device and never synced. Unset → on for a
/// phone (shortest side < 600 pt), off for a tablet.
class RemindOnDeviceNotifier extends Notifier<bool> {
  static const prefsKey = 'calendar.remindOnDevice';

  /// Completes once the stored value (if any) has been applied.
  late Future<void> loaded;
  bool _setByUser = false;

  @override
  bool build() {
    final byDefault =
        ref.watch(deviceShortestSideProvider) < kInlineVideoMinShortestSide;
    loaded = _load();
    return byDefault;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || _setByUser) return;
    final stored = prefs.getBool(prefsKey);
    if (stored != null) state = stored;
  }

  Future<void> set(bool value) async {
    _setByUser = true;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }
}

final remindOnDeviceProvider = NotifierProvider<RemindOnDeviceNotifier, bool>(
  RemindOnDeviceNotifier.new,
);

/// True when calendar reminders are due on this device but notification
/// permission is not granted; drives the calendar screen's banner.
class CalendarPermissionDeniedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool denied) => state = denied;
}

final calendarPermissionDeniedProvider =
    NotifierProvider<CalendarPermissionDeniedNotifier, bool>(
      CalendarPermissionDeniedNotifier.new,
    );
