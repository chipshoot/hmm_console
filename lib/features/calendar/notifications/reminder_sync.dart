import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/data/data_mode.dart';
import '../../../core/i18n/app_localizations_now.dart';
import '../contract/calendar_errors.dart';
import '../contract/i_calendar_repository.dart';
import '../contract/i_reminder_scheduler.dart';
import '../data/local_calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/occurrence.dart';
import '../domain/recurrence_expander.dart';
import '../presentation/linked_event_title.dart';
import '../states/calendar_providers.dart';
import '../states/remind_on_device_provider.dart';
import '../states/reminders_seen_provider.dart';
import 'local_reminder_scheduler.dart';
import 'notification_gateway.dart';
import 'reminder_plan.dart';

bool _tzDataLoaded = false;
bool _deviceZoneKnown = false;

/// True once the device zone has been read into `tz.local`. While false
/// (before the first read, in widget tests, or when the read failed) the
/// platform zone (`DateTime` local time) applies, never UTC.
bool get deviceZoneKnown => _deviceZoneKnown;

Future<String> _readPlatformZone() async =>
    (await FlutterTimezone.getLocalTimezone()).identifier;

/// Loads the time-zone database once and sets `tz.local` to the device's
/// zone as [readZone] reports it. Called at start and on every resume (R-19),
/// so travel or a zone change in Settings is picked up. When the zone cannot
/// be read, [deviceZoneKnown] turns false and the platform zone is used.
Future<void> initDeviceTimeZone({
  Future<String> Function() readZone = _readPlatformZone,
}) async {
  if (!_tzDataLoaded) {
    tzdata.initializeTimeZones();
    _tzDataLoaded = true;
  }
  try {
    tz.setLocalLocation(tz.getLocation(await readZone()));
    _deviceZoneKnown = true;
  } catch (e) {
    debugPrint(
      'ReminderSync: device time zone unavailable (${e.runtimeType}); '
      'using the platform zone',
    );
    _deviceZoneKnown = false;
  }
}

/// Wall-clock time in the device zone → UTC instant: `tz.local` once the
/// device zone is known, else the platform zone.
DateTime deviceLocalResolver(int y, int m, int d, int hh, int mm) =>
    _deviceZoneKnown
    ? tz.TZDateTime(tz.local, y, m, d, hh, mm).toUtc()
    : defaultLocalResolver(y, m, d, hh, mm);

/// [utc] as wall-clock time in the device zone ([deviceZoneKnown]), else
/// in the platform zone.
DateTime deviceLocalTimeOf(DateTime utc) =>
    _deviceZoneKnown ? tz.TZDateTime.from(utc, tz.local) : utc.toLocal();

/// Short time of day in [locale]: 24-hour (`19:00`) when [use24h] (default:
/// the device setting), else the locale's 12-hour form (`7:00 PM`).
String Function(DateTime wall) shortTimeFormatter(
  String locale, {
  bool? use24h,
}) {
  final h24 = use24h ?? PlatformDispatcher.instance.alwaysUse24HourFormat;
  return (wall) {
    try {
      return (h24 ? DateFormat.Hm(locale) : DateFormat.jm(locale)).format(wall);
    } catch (_) {
      // Locale data not loaded: plain HH:mm or h:mm AM/PM.
      final mm = wall.minute.toString().padLeft(2, '0');
      if (h24) return '${wall.hour.toString().padLeft(2, '0')}:$mm';
      final h = wall.hour % 12 == 0 ? 12 : wall.hour % 12;
      return '$h:$mm ${wall.hour < 12 ? 'AM' : 'PM'}';
    }
  };
}

/// R-21: "19:00 · Evening walk" — the occurrence's start in the device zone,
/// or "All day · Title" (localized) for an all-day occurrence.
String reminderTitle(
  CalendarEvent e,
  Occurrence o, {
  required String allDayLabel,
  required String Function(DateTime wall) formatTime,
  DateTime Function(DateTime utc) toLocal = deviceLocalTimeOf,
  String Function(CalendarEvent, Occurrence)? titleOf,
}) {
  final title = titleOf != null ? titleOf(e, o) : (o.titleOverride ?? e.title);
  final when = o.allDay ? allDayLabel : formatTime(toLocal(o.start));
  return '$when · $title';
}

/// English, device 24-hour setting. The app passes the localized
/// [reminderTitleFormatProvider] instead.
String defaultReminderTitle(CalendarEvent e, Occurrence o) => reminderTitle(
  e,
  o,
  allDayLabel: 'All day',
  formatTime: shortTimeFormatter('en'),
);

/// The notification title in the app's language (the chosen locale, else
/// the platform's), built without a BuildContext.
final reminderTitleFormatProvider =
    Provider<String Function(CalendarEvent, Occurrence)>((ref) {
      final l = ref.watch(appLocalizationsNowProvider);
      final formatTime = shortTimeFormatter(l.localeName);
      return (e, o) => reminderTitle(
        e,
        o,
        allDayLabel: l.calendarAllDay,
        formatTime: formatTime,
        titleOf: (e, o) => eventTitle(e, o, l),
      );
    });

DateTime _utcNow() => DateTime.now().toUtc();

Future<void> _noBadge(int count) async {}

/// Keeps this device's pending calendar reminders in step with the events.
///
/// Runs on [start], on return to the foreground and on each repository
/// change, all debounced by [debounce]. Each run reads every readable event,
/// plans with the device resolver and reschedules. With "Remind on this
/// device" off, or in cloud API mode (no calendar repository), it cancels the
/// calendar reminders instead. Every run sets the app icon badge: the unseen
/// count, or 0 when no reminder shows on this device.
class ReminderSync with WidgetsBindingObserver {
  ReminderSync({
    required ICalendarRepository Function() repository,
    required IReminderScheduler scheduler,
    required Future<bool> Function() permissionGranted,
    required bool Function() remindOnDevice,
    required Future<bool> Function() permissionAsked,
    required Future<bool?> Function() askPermissionOnce,
    required void Function(bool denied) onPermissionChecked,
    LocalResolver resolve = deviceLocalResolver,
    String Function(CalendarEvent, Occurrence) formatTitle =
        defaultReminderTitle,
    DateTime Function() clock = _utcNow,
    Future<void> Function()? refreshZone,
    Future<DateTime?> Function() readSeenAt = readRemindersSeenAt,
    Future<void> Function(DateTime utc) writeSeenAt = writeRemindersSeenAt,
    Future<void> Function(int count) setBadge = _noBadge,
    Duration debounce = const Duration(seconds: 1),
    bool observeLifecycle = true,
  }) : _repository = repository,
       _scheduler = scheduler,
       _permissionGranted = permissionGranted,
       _remindOnDevice = remindOnDevice,
       _permissionAsked = permissionAsked,
       _askPermissionOnce = askPermissionOnce,
       _onPermissionChecked = onPermissionChecked,
       _resolve = resolve,
       _formatTitle = formatTitle,
       _clock = clock,
       _refreshZone = refreshZone,
       _readSeenAt = readSeenAt,
       _writeSeenAt = writeSeenAt,
       _setBadge = setBadge,
       _debounce = debounce,
       _observeLifecycle = observeLifecycle;

  final ICalendarRepository Function() _repository;
  final IReminderScheduler _scheduler;
  final Future<bool> Function() _permissionGranted;
  final bool Function() _remindOnDevice;
  final Future<bool> Function() _permissionAsked;

  /// Asks when never asked (returns the answer), else returns null.
  final Future<bool?> Function() _askPermissionOnce;
  final void Function(bool denied) _onPermissionChecked;
  final LocalResolver _resolve;
  final String Function(CalendarEvent, Occurrence) _formatTitle;
  final DateTime Function() _clock;

  /// Re-reads the device zone; run on every resume before planning (R-19).
  final Future<void> Function()? _refreshZone;

  /// The reminders inbox's seen instant ([kRemindersSeenAtKey]).
  final Future<DateTime?> Function() _readSeenAt;
  final Future<void> Function(DateTime utc) _writeSeenAt;

  /// Sets the app icon badge (iOS; a no-op elsewhere).
  final Future<void> Function(int count) _setBadge;
  final Duration _debounce;
  final bool _observeLifecycle;

  bool _started = false;
  StreamSubscription<void>? _changesSub;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _rerun = false;

  /// The previous run found "Remind on this device" off, or Cloud API mode.
  bool _lastRunOff = false;

  /// Idempotent. Subscribes to changes and the app lifecycle, then triggers.
  void start() {
    if (_started) return;
    _started = true;
    if (_observeLifecycle) WidgetsBinding.instance.addObserver(this);
    resubscribe();
    trigger();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    if (_observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    unawaited(_changesSub?.cancel());
    _changesSub = null;
  }

  /// Re-attaches to the current repository's `changes()` (after a data-mode
  /// switch). Cloud API mode has no repository, so nothing is attached.
  void resubscribe() {
    if (!_started) return;
    unawaited(_changesSub?.cancel());
    _changesSub = null;
    try {
      _changesSub = _repository().changes().listen(
        (_) => trigger(),
        // Logged, never thrown; the subscription stays and the next change
        // (or resume) runs as usual.
        onError: (Object e) =>
            debugPrint('ReminderSync: changes failed (${e.runtimeType})'),
      );
    } catch (e) {
      // Cloud API mode has no calendar; runs just cancel. Anything else is
      // logged once and the next trigger tries again.
      if (!isCalendarCloudApiUnavailable(e)) {
        debugPrint('ReminderSync: subscribe failed (${e.runtimeType})');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final refresh = _refreshZone;
    if (refresh == null) {
      trigger();
      return;
    }
    unawaited(() async {
      try {
        await refresh();
      } catch (e) {
        debugPrint('ReminderSync: zone refresh failed (${e.runtimeType})');
      }
      trigger();
    }());
  }

  /// Schedules a run after the debounce; a later trigger restarts the wait.
  void trigger() {
    if (!_started) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      _timer = null;
      unawaited(runNow());
    });
  }

  /// One run now; a run requested while one is in flight runs once after it.
  Future<void> runNow() async {
    if (_inFlight != null) {
      _rerun = true;
      return _inFlight;
    }
    final run = _run();
    _inFlight = run;
    try {
      await run;
    } finally {
      _inFlight = null;
    }
    if (_rerun) {
      _rerun = false;
      await runNow();
    }
  }

  Future<void> _run() async {
    try {
      if (!_remindOnDevice()) {
        _onPermissionChecked(false);
        await _scheduler.cancelAll();
        await _nothingShows();
        return;
      }
      final ICalendarRepository repo;
      try {
        repo = _repository();
      } catch (e) {
        // R-12: the helper also sees through Riverpod's ProviderException.
        if (!isCalendarCloudApiUnavailable(e)) rethrow;
        _onPermissionChecked(false);
        await _scheduler.cancelAll();
        // Cloud API mode has no calendar, so no reminder shows either.
        await _nothingShows();
        return;
      }
      final now = _clock().toUtc();
      final backOn = _lastRunOff;
      if (backOn) {
        // Back on after an off (or Cloud API) run: reminders that fired since
        // that run never showed either, so the unseen count restarts from
        // now. Stored before the events load, so a failing load cannot leave
        // a stale count.
        await _markSeen(now);
      }
      final events = await loadReminderEvents(repo, now);
      final int unseenNow;
      if (backOn) {
        // Cleared only on a run that reaches planning: a failed load keeps
        // it, and the next run restarts the count from its own now.
        _lastRunOff = false;
        unseenNow = 0;
      } else {
        unseenNow = await _unseenNow(events, now);
      }
      // Every run, so the icon follows the count after edits, done marks and
      // inbox visits, not only when a reminder fires.
      await _updateBadge(unseenNow);
      final plan = planReminders(
        events: events,
        nowUtc: now,
        resolve: _resolve,
        formatTitle: _formatTitle,
        unseenNow: unseenNow,
      );
      if (plan.isEmpty) {
        // Nothing due: clear stale entries without consulting permission, so
        // the banner never shows for a device with no reminders.
        _onPermissionChecked(false);
        await _scheduler.reschedule(const []);
        return;
      }
      var granted = await _permissionGranted();
      if (!granted) {
        // R-18: reminders are due and the owner was never asked (an iPhone
        // whose events all came from the iPad): ask once, here.
        granted = await _askPermissionOnce() ?? false;
      }
      // The banner is for an owner who was asked and said no (R-11), not
      // for a device that has never been asked.
      _onPermissionChecked(!granted && await _permissionAsked());
      if (!granted) return;
      await _scheduler.reschedule(plan);
    } catch (e) {
      debugPrint('ReminderSync: run failed (${e.runtimeType})');
    }
  }

  /// Nothing shows on this device ("Remind on this device" off, or Cloud API
  /// mode), so whatever fires now must never count as unseen once reminders
  /// show again, and the icon badge reads 0.
  Future<void> _nothingShows() async {
    _lastRunOff = true;
    await _markSeen(_clock().toUtc());
    await _updateBadge(0);
  }

  /// Sets the icon badge to [count]. A failure is logged, never thrown: a
  /// stale badge is cosmetic, delivery goes on.
  Future<void> _updateBadge(int count) async {
    try {
      await _setBadge(count);
    } catch (e) {
      debugPrint('ReminderSync: badge not set (${e.runtimeType})');
    }
  }

  /// Stores [now] as seen. A failure is logged, never thrown: the badge may
  /// then count a few extra reminders, but delivery goes on.
  Future<void> _markSeen(DateTime now) async {
    try {
      await _writeSeenAt(now);
    } catch (e) {
      debugPrint('ReminderSync: seen state not stored (${e.runtimeType})');
    }
  }

  /// Reminders fired since the inbox was last seen, within the inbox's
  /// 7-day window. A first run stores now as seen, so earlier history never
  /// counts. When the seen state cannot be read or written the count is 0:
  /// badge numbers start low, but the reminders are still scheduled.
  Future<int> _unseenNow(List<CalendarEvent> events, DateTime now) async {
    try {
      final seenAt = await _readSeenAt();
      if (seenAt == null) {
        await _writeSeenAt(now);
        return 0;
      }
      final windowStart = now.subtract(kRemindersInboxWindow);
      final from = seenAt.isAfter(windowStart) ? seenAt : windowStart;
      return firedReminders(
        events: events,
        fromUtc: from,
        toUtc: now,
        resolve: _resolve,
        formatTitle: _formatTitle,
      ).length;
    } catch (e) {
      debugPrint('ReminderSync: seen state unavailable (${e.runtimeType})');
      return 0;
    }
  }
}

/// Every event a reminder could have fired from within the inbox window or
/// may fire from later: all readable local events (unreadable ones skipped),
/// else events from the window's start on. Shared by [ReminderSync] and the
/// reminders inbox, so both see the same events.
Future<List<CalendarEvent>> loadReminderEvents(
  ICalendarRepository repo,
  DateTime now,
) async {
  if (repo is LocalCalendarRepository) {
    return [
      for (final r in await repo.readAll())
        if (r is CalendarEventReadable) r.event,
    ];
  }
  // From the inbox window's start. This relies on minutesBefore >= 0 (the
  // editor enforces it): an occurrence then never starts before its
  // reminder fires, so this covers every reminder fired in the window.
  return repo.eventsBetween(
    now.subtract(kRemindersInboxWindow),
    now.add(const Duration(days: 3660)),
  );
}

/// Built once and kept alive by the app root, which calls [ReminderSync.start]
/// after the time zone and the notification plugin are initialised.
final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final gateway = ref.watch(notificationGatewayProvider);
  final scheduler = ref.watch(reminderSchedulerProvider);
  final sync = ReminderSync(
    repository: () => ref.read(calendarRepositoryProvider),
    scheduler: scheduler,
    permissionGranted: gateway.permissionGranted,
    remindOnDevice: () => ref.read(remindOnDeviceProvider),
    permissionAsked: calendarPermissionAsked,
    askPermissionOnce: () => askPermissionOnceIfNeverAsked(
      request: scheduler.requestPermission,
      markAsked: (granted) => ref
          .read(calendarPermissionDeniedProvider.notifier)
          .markPermissionAsked(granted: granted),
    ),
    onPermissionChecked: (denied) =>
        ref.read(calendarPermissionDeniedProvider.notifier).set(denied),
    refreshZone: initDeviceTimeZone,
    // Read per run, so a language change applies at the next run.
    formatTitle: (e, o) => ref.read(reminderTitleFormatProvider)(e, o),
    // Through the app state, so the inbox and the bell see every write.
    readSeenAt: () => ref.read(remindersSeenAtProvider.future),
    writeSeenAt: (utc) => ref.read(remindersSeenAtProvider.notifier).write(utc),
    setBadge: gateway.setBadge,
  );
  ref.listen(reminderTitleFormatProvider, (_, _) => sync.trigger());
  ref.listen<bool>(remindOnDeviceProvider, (_, _) => sync.trigger());
  ref.listen<DataMode>(dataModeProvider, (_, _) {
    sync.resubscribe();
    sync.trigger();
  });
  ref.onDispose(sync.stop);
  return sync;
});
