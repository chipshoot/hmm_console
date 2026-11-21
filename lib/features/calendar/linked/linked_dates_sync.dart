import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_author_account_name_provider.dart';
import '../../../core/data/data_mode.dart';
import '../../../core/data/repository_providers.dart';
import '../../../core/data/sync/sync_controller.dart';
import '../../../core/data/sync/sync_orchestrator.dart';
import '../../../core/i18n/app_localizations_now.dart';
import '../contract/calendar_errors.dart';
import '../contract/dated_note.dart';
import '../states/calendar_providers.dart';
import 'dated_note_sources_provider.dart';
import 'linked_dates_matcher.dart';

/// Runs [LinkedDatesMatcher] at start, on resume, when notes change and after
/// each finished sync. Never while a sync runs, never in Cloud API mode.
class LinkedDatesSync with WidgetsBindingObserver {
  LinkedDatesSync({
    required this.sources,
    required this.matcher,
    required this.isCloudApi,
    required this.noteChanges,
    required this.syncEvents,
    required this.isSyncing,
    required this.runExclusive,
    this.waitingForFirstSync = _no,
    this.lastSyncFailed = _no,
    this.debounce = const Duration(seconds: 2),
    this.retryDelay = const Duration(seconds: 2),
  });

  static bool _no() => false;

  /// Read per run.
  final List<DatedNoteSource> Function() sources;

  /// May throw the Cloud API unavailable error.
  final LinkedDatesMatcher Function() matcher;
  final bool Function() isCloudApi;
  final Stream<void> Function() noteChanges;

  /// Notifies on every sync status change; a run follows once none is running.
  final Listenable syncEvents;
  final bool Function() isSyncing;
  final Future<T?> Function<T>(Future<T> Function() body) runExclusive;

  /// True while cloud sync is on and this session's first sync has not
  /// finished: local data may be stale, so runs wait for [syncEvents].
  final bool Function() waitingForFirstSync;

  /// True when the last sync failed: the data may be partial, so the run
  /// creates and updates but removes nothing.
  final bool Function() lastSyncFailed;
  final Duration debounce;

  /// Wait before re-attaching a notes watch that failed or ended.
  final Duration retryDelay;

  Timer? _timer;
  Timer? _retry;
  StreamSubscription<void>? _notes;
  bool _started = false;
  bool _disposed = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    syncEvents.addListener(_afterSync);
    _watch();
    trigger();
  }

  // The notes watch can fail or end, e.g. at start-up before the current
  // author is ready: it is re-attached after [retryDelay] so changes are
  // never missed for the rest of the session.
  void _watch() {
    if (_disposed) return;
    void again() {
      _notes = null;
      _retry?.cancel();
      if (!_disposed) _retry = Timer(retryDelay, _watch);
    }

    try {
      _notes = noteChanges().listen(
        (_) => trigger(),
        onError: (Object e) {
          debugPrint('Linked dates watch failed (${e.runtimeType})');
          again();
        },
        onDone: again,
        cancelOnError: true,
      );
    } catch (e) {
      // Note repository unavailable (Cloud API): nothing to watch.
      debugPrint('Linked dates watch failed (${e.runtimeType})');
    }
  }

  void _afterSync() {
    if (!isSyncing()) trigger();
  }

  /// Debounced run.
  void trigger() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(runNow()));
  }

  /// Runs the matcher once now. Null when it did not run (Cloud API, the
  /// first sync not finished, a source failed, or the lock was held, which
  /// schedules a retry).
  Future<MatchResult?> runNow() async {
    if (_disposed || isCloudApi() || waitingForFirstSync()) return null;
    try {
      final LinkedDatesMatcher m;
      try {
        m = matcher();
      } catch (e) {
        if (isCalendarCloudApiUnavailable(e)) return null;
        rethrow;
      }
      var bodyRan = false;
      final result = await runExclusive<MatchResult?>(() async {
        bodyRan = true;
        final list = sources();
        final dates = <DatedItem>[];
        final subsystems = <String>{};
        try {
          for (final s in list) {
            for (final n in await s.datedNotes()) {
              dates.addAll(n.dates);
            }
            subsystems.addAll(s.subsystems);
          }
        } catch (e) {
          debugPrint('Linked dates skipped (${e.runtimeType})');
          return null;
        }
        return m.apply(
          wanted: dates,
          subsystems: subsystems,
          removals: !lastSyncFailed(),
        );
      });
      // The lock was held (a sync, the note purge): try again later through
      // the normal debounce so the run is not lost.
      if (!bodyRan) trigger();
      return result;
    } catch (e) {
      debugPrint('Linked dates skipped (${e.runtimeType})');
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) trigger();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _retry?.cancel();
    unawaited(_notes?.cancel());
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      syncEvents.removeListener(_afterSync);
    }
  }
}

/// Rebuilt with the sync controller and data mode. The app root keeps it
/// alive and starts each new instance.
final linkedDatesSyncProvider = Provider<LinkedDatesSync>((ref) {
  final mode = ref.watch(dataModeProvider);
  final controller = ref.watch(syncControllerProvider);
  final cloudSync = ref.watch(syncOrchestratorProvider).isActive;
  final cloudApi = mode == DataMode.cloudApi;
  final sync = LinkedDatesSync(
    sources: () => ref.read(datedNoteSourcesProvider),
    matcher: () => LinkedDatesMatcher(
      ref.read(calendarRepositoryProvider),
      l: ref.read(appLocalizationsNowProvider),
    ),
    isCloudApi: () => cloudApi,
    noteChanges: () => cloudApi
        ? const Stream<void>.empty()
        : ref.read(hmmNoteRepositoryProvider).watchNotes().map((_) {}),
    syncEvents: controller,
    isSyncing: () => controller.status.isSyncing,
    runExclusive: controller.runExclusive,
    waitingForFirstSync: () =>
        cloudSync && controller.status.lastSyncAt == null,
    lastSyncFailed: () =>
        cloudSync && controller.status.lastResult?.success == false,
  );
  // The start run fails while the current author is still loading; run
  // again once it is ready.
  if (!cloudApi) {
    ref.listen(currentAuthorProvider, (prev, next) {
      if (next.hasValue && !(prev?.hasValue ?? false)) sync.trigger();
    });
  }
  ref.onDispose(sync.dispose);
  return sync;
});
