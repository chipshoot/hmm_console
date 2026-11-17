import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../notes/presentation/widgets/video_tile.dart'
    show kInlineVideoMinShortestSide;

/// Shortest side of this device's screen in logical points, or null while
/// unknown. Starts from [platformShortestSide]; the app root calls
/// [DeviceShortestSideNotifier.set] after the first frame, when the view is
/// guaranteed to exist (with the UIScene lifecycle there may be no view
/// before `runApp`).
class DeviceShortestSideNotifier extends Notifier<double?> {
  /// [initial] fixes the starting value (tests); otherwise the platform is
  /// asked.
  DeviceShortestSideNotifier([this._initial]);

  final double? _initial;

  @override
  double? build() => _initial ?? platformShortestSide();

  /// A missing or non-positive size leaves the value unknown.
  void set(double? side) {
    final v = side != null && side > 0 ? side : null;
    if (v != null || state == null) state = v;
  }
}

final deviceShortestSideProvider =
    NotifierProvider<DeviceShortestSideNotifier, double?>(
      DeviceShortestSideNotifier.new,
    );

/// Shortest side of [view]'s display (the physical screen, so an iPad in
/// Split View still counts as a tablet), else of the view itself; null when
/// neither has a size.
double? shortestSideOfView(FlutterView view) {
  try {
    final d = view.display;
    final side = d.size.shortestSide / d.devicePixelRatio;
    if (side > 0) return side;
  } catch (_) {
    // No display attached yet; fall through to the view.
  }
  if (view.devicePixelRatio <= 0) return null;
  final side = view.physicalSize.shortestSide / view.devicePixelRatio;
  return side > 0 ? side : null;
}

/// Shortest side from the first view, else the first display; null when the
/// engine has reported neither yet.
double? platformShortestSide() {
  final p = PlatformDispatcher.instance;
  if (p.views.isNotEmpty) {
    final side = shortestSideOfView(p.views.first);
    if (side != null) return side;
  }
  for (final d in p.displays) {
    if (d.devicePixelRatio <= 0) continue;
    final side = d.size.shortestSide / d.devicePixelRatio;
    if (side > 0) return side;
  }
  return null;
}

/// "Remind on this device": per device and never synced. Unset → on for a
/// phone (shortest side < 600 pt), off for a tablet. An unknown size counts
/// as off, so a tablet whose size isn't known yet never double-fires with
/// the phone; the value is recomputed once the size arrives.
class RemindOnDeviceNotifier extends Notifier<bool> {
  static const prefsKey = 'calendar.remindOnDevice';

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

final remindOnDeviceProvider = NotifierProvider<RemindOnDeviceNotifier, bool>(
  RemindOnDeviceNotifier.new,
);

/// Set once the app has asked for notification permission (Task 8 calls
/// [CalendarPermissionDeniedNotifier.markPermissionAsked]). Per device.
const kCalendarPermissionAskedKey = 'calendar.permissionAsked';

Future<bool> calendarPermissionAsked() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kCalendarPermissionAskedKey) ?? false;
}

/// True when calendar reminders are due on this device, the owner has been
/// asked for notification permission, and it is not granted (asked &&
/// !granted). Drives the calendar screen's banner; never true on a device
/// that has not been asked yet.
class CalendarPermissionDeniedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool denied) => state = denied;

  /// Records that the permission prompt was shown. Task 8 calls this when it
  /// asks; [granted] is the prompt's answer and updates the banner at once.
  Future<void> markPermissionAsked({required bool granted}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kCalendarPermissionAskedKey, true);
    if (ref.mounted) state = !granted;
  }
}

final calendarPermissionDeniedProvider =
    NotifierProvider<CalendarPermissionDeniedNotifier, bool>(
      CalendarPermissionDeniedNotifier.new,
    );
