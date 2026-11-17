import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/data/data_mode.dart';
import '../contract/calendar_errors.dart';
import '../contract/i_calendar_repository.dart';
import '../contract/i_reminder_scheduler.dart';
import '../data/local_calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/occurrence.dart';
import '../domain/recurrence_expander.dart';
import '../states/calendar_providers.dart';
import '../states/remind_on_device_provider.dart';
import 'local_reminder_scheduler.dart';
import 'notification_gateway.dart';
import 'reminder_plan.dart';

/// Loads the time-zone database and sets `tz.local` to the device's zone,
/// falling back to UTC when the zone cannot be read.
Future<void> initDeviceTimeZone() async {
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (e) {
    debugPrint(
      'ReminderSync: device time zone unavailable (${e.runtimeType}); using UTC',
    );
    tz.setLocalLocation(tz.UTC);
  }
}

/// Wall-clock time in the device zone (`tz.local`) → UTC instant.
DateTime deviceLocalResolver(int y, int m, int d, int hh, int mm) =>
    tz.TZDateTime(tz.local, y, m, d, hh, mm).toUtc();

String defaultReminderTitle(CalendarEvent e, Occurrence o) =>
    o.titleOverride ?? e.title;

DateTime _utcNow() => DateTime.now().toUtc();

/// Keeps this device's pending calendar reminders in step with the events.
///
/// Runs on [start], on return to the foreground and on each repository
/// change, all debounced by [debounce]. Each run reads every readable event,
/// plans with the device resolver and reschedules. With "Remind on this
/// device" off, or in cloud API mode (no calendar repository), it cancels the
/// calendar reminders instead.
class ReminderSync with WidgetsBindingObserver {
  ReminderSync({
    required ICalendarRepository Function() repository,
    required IReminderScheduler scheduler,
    required Future<bool> Function() permissionGranted,
    required bool Function() remindOnDevice,
    required Future<bool> Function() permissionAsked,
    required void Function(bool denied) onPermissionChecked,
    LocalResolver resolve = deviceLocalResolver,
    String Function(CalendarEvent, Occurrence) formatTitle =
        defaultReminderTitle,
    DateTime Function() clock = _utcNow,
    Duration debounce = const Duration(seconds: 1),
    bool observeLifecycle = true,
  }) : _repository = repository,
       _scheduler = scheduler,
       _permissionGranted = permissionGranted,
       _remindOnDevice = remindOnDevice,
       _permissionAsked = permissionAsked,
       _onPermissionChecked = onPermissionChecked,
       _resolve = resolve,
       _formatTitle = formatTitle,
       _clock = clock,
       _debounce = debounce,
       _observeLifecycle = observeLifecycle;

  final ICalendarRepository Function() _repository;
  final IReminderScheduler _scheduler;
  final Future<bool> Function() _permissionGranted;
  final bool Function() _remindOnDevice;
  final Future<bool> Function() _permissionAsked;
  final void Function(bool denied) _onPermissionChecked;
  final LocalResolver _resolve;
  final String Function(CalendarEvent, Occurrence) _formatTitle;
  final DateTime Function() _clock;
  final Duration _debounce;
  final bool _observeLifecycle;

  bool _started = false;
  StreamSubscription<void>? _changesSub;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _rerun = false;

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
      _changesSub = _repository().changes().listen((_) => trigger());
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
    if (state == AppLifecycleState.resumed) trigger();
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
        return;
      }
      final now = _clock().toUtc();
      final plan = planReminders(
        events: await _loadEvents(repo, now),
        nowUtc: now,
        resolve: _resolve,
        formatTitle: _formatTitle,
      );
      if (plan.isEmpty) {
        // Nothing due: clear stale entries without consulting permission, so
        // the banner never shows for a device with no reminders.
        _onPermissionChecked(false);
        await _scheduler.reschedule(const []);
        return;
      }
      final granted = await _permissionGranted();
      // The banner is for an owner who was asked and said no (R-11), not
      // for a device that has never been asked.
      _onPermissionChecked(!granted && await _permissionAsked());
      if (!granted) return;
      await _scheduler.reschedule(plan);
    } catch (e) {
      debugPrint('ReminderSync: run failed (${e.runtimeType})');
    }
  }

  static Future<List<CalendarEvent>> _loadEvents(
    ICalendarRepository repo,
    DateTime now,
  ) async {
    if (repo is LocalCalendarRepository) {
      // Every event, unreadable ones skipped.
      return [
        for (final r in await repo.readAll())
          if (r is CalendarEventReadable) r.event,
      ];
    }
    return repo.eventsBetween(now, now.add(const Duration(days: 3660)));
  }
}

/// Built once and kept alive by the app root, which calls [ReminderSync.start]
/// after the time zone and the notification plugin are initialised.
final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final gateway = ref.watch(notificationGatewayProvider);
  final sync = ReminderSync(
    repository: () => ref.read(calendarRepositoryProvider),
    scheduler: ref.watch(reminderSchedulerProvider),
    permissionGranted: gateway.permissionGranted,
    remindOnDevice: () => ref.read(remindOnDeviceProvider),
    permissionAsked: calendarPermissionAsked,
    onPermissionChecked: (denied) =>
        ref.read(calendarPermissionDeniedProvider.notifier).set(denied),
  );
  ref.listen<bool>(remindOnDeviceProvider, (_, _) => sync.trigger());
  ref.listen<DataMode>(dataModeProvider, (_, _) {
    sync.resubscribe();
    sync.trigger();
  });
  ref.onDispose(sync.stop);
  return sync;
});
