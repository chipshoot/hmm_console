import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_mode.dart';
import '../../../core/data/repository_providers.dart';
import '../../../core/data/sync/sync_controller.dart';
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
    this.debounce = const Duration(seconds: 2),
  });

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
  final Duration debounce;

  Timer? _timer;
  StreamSubscription<void>? _notes;
  bool _started = false;
  bool _disposed = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    syncEvents.addListener(_afterSync);
    try {
      _notes = noteChanges().listen(
        (_) => trigger(),
        onError: (Object e) =>
            debugPrint('Linked dates watch failed (${e.runtimeType})'),
      );
    } catch (e) {
      // Note repository unavailable (Cloud API): nothing to watch.
      debugPrint('Linked dates watch failed (${e.runtimeType})');
    }
    trigger();
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

  /// Runs the matcher once now. Null when it did not run (Cloud API, a
  /// source failed, or the lock was held, which schedules a retry).
  Future<MatchResult?> runNow() async {
    if (_disposed || isCloudApi()) return null;
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
        return m.apply(wanted: dates, subsystems: subsystems);
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
  );
  ref.onDispose(sync.dispose);
  return sync;
});
