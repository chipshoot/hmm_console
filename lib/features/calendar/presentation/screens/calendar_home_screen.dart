import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/widgets/adaptive_icon.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../contract/calendar_errors.dart';
import '../../data/holiday_cache.dart';
import '../../domain/calendar_event.dart';
import '../../domain/holidays.dart';
import '../../domain/linked_event.dart';
import '../../domain/lunar.dart';
import '../../states/calendar_providers.dart';
import '../../states/calendar_view_state.dart';
import '../../states/holiday_providers.dart';
import '../../states/holiday_settings_providers.dart';
import '../../states/remind_on_device_provider.dart';
import '../../states/show_lunar_provider.dart';
import '../widgets/agenda_list.dart';
import '../widgets/calendar_cloud_api_message.dart';
import '../widgets/month_grid.dart';
import '../widgets/permission_banner.dart';

/// Same breakpoint as the Notes sidebar's docked layout.
const double kCalendarWideBreakpoint = 1000;

enum _RowAction { edit, deleteOne, deleteSeries }

/// Month grid plus the selected day's agenda.
class CalendarHomeScreen extends ConsumerStatefulWidget {
  const CalendarHomeScreen({super.key});

  @override
  ConsumerState<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends ConsumerState<CalendarHomeScreen> {
  void _add() {
    final d = ref.read(selectedDayProvider);
    final day =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    context.pushNamed(
      RouterNames.calendarEventCreate.name,
      queryParameters: {'day': day},
    );
  }

  void _open(AgendaItem i) => context.pushNamed(
    RouterNames.calendarEvent.name,
    pathParameters: {'id': i.event.id},
    queryParameters: {'at': i.occurrence.originalStart.wireKey},
  );

  OccurrenceOverride _overrideFor(AgendaItem i, OccurrenceStatus s) {
    final key = i.occurrence.originalStart.wireKey;
    for (final o in i.event.occurrences) {
      if (o.originalStart.wireKey == key) return o.copyWith(status: s);
    }
    return OccurrenceOverride(
      originalStart: i.occurrence.originalStart,
      status: s,
    );
  }

  /// Runs [change] on the event, with Undo = saving the snapshot taken first
  /// (R-6). Everything the snackbar needs is captured before any await.
  Future<void> _undoable(
    AgendaItem i, {
    required Future<void> Function() change,
    required String done,
    required String failed,
    required String undone,
  }) {
    final l = AppLocalizations.of(context);
    final repo = ref.read(calendarRepositoryProvider);
    final snapshot = i.event;
    return showUndoableAction(
      context,
      busyKey: ('calendar', snapshot.id, i.occurrence.originalStart.wireKey),
      run: change,
      undo: () async {
        await repo.saveEvent(snapshot);
      },
      done: done,
      failed: failed,
      undone: undone,
      undoFailed: l.calendarUndoFailed,
    );
  }

  Future<void> _mark(AgendaItem i, OccurrenceStatus s) {
    final l = AppLocalizations.of(context);
    final repo = ref.read(calendarRepositoryProvider);
    final isDone = s == OccurrenceStatus.done;
    return _undoable(
      i,
      change: () async {
        await repo.setOccurrence(i.event.id, _overrideFor(i, s));
      },
      done: isDone ? l.calendarOccurrenceDone : l.calendarOccurrenceSkipped,
      failed: isDone
          ? l.calendarOccurrenceDoneFailed
          : l.calendarOccurrenceSkippedFailed,
      undone: isDone
          ? l.calendarOccurrenceDoneUndone
          : l.calendarOccurrenceSkippedUndone,
    );
  }

  Future<_RowAction?> _pickAction({required bool deletable}) {
    final l = AppLocalizations.of(context);
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return showCupertinoModalPopup<_RowAction>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, _RowAction.edit),
              child: Text(l.calendarEdit),
            ),
            if (deletable) ...[
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, _RowAction.deleteOne),
                child: Text(l.calendarDeleteThis),
              ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, _RowAction.deleteSeries),
                child: Text(l.calendarDeleteSeries),
              ),
            ],
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
        ),
      );
    }
    return showModalBottomSheet<_RowAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.calendarEdit),
              onTap: () => Navigator.pop(ctx, _RowAction.edit),
            ),
            if (deletable) ...[
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(l.calendarDeleteThis),
                onTap: () => Navigator.pop(ctx, _RowAction.deleteOne),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l.calendarDeleteSeries),
                onTap: () => Navigator.pop(ctx, _RowAction.deleteSeries),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _menu(AgendaItem i) async {
    final action = await _pickAction(
      // A linked event is removed at its source, never here.
      deletable: linkedInfoOf(i.event) == null,
    );
    if (!mounted || action == null) return;
    final l = AppLocalizations.of(context);
    final repo = ref.read(calendarRepositoryProvider);
    switch (action) {
      case _RowAction.edit:
        context.pushNamed(
          RouterNames.calendarEventEdit.name,
          pathParameters: {'id': i.event.id},
          queryParameters: {'at': i.occurrence.originalStart.wireKey},
        );
      case _RowAction.deleteOne:
        await _undoable(
          i,
          change: () async {
            await repo.setOccurrence(
              i.event.id,
              _overrideFor(i, OccurrenceStatus.cancelled),
            );
          },
          done: l.calendarOccurrenceDeleted,
          failed: l.calendarOccurrenceDeleteFailed,
          undone: l.calendarOccurrenceDeleteUndone,
        );
      case _RowAction.deleteSeries:
        await _undoable(
          i,
          change: () => repo.deleteEvent(i.event.id),
          done: l.calendarSeriesDeleted,
          failed: l.calendarSeriesDeleteFailed,
          undone: l.calendarSeriesDeleteUndone,
        );
    }
  }

  /// Offers Hide for a downloaded holiday. The sheet's action pops and hides
  /// synchronously, so no context is used after an await.
  void _holidayTap(HolidayLine h) {
    final l = AppLocalizations.of(context);
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(h.name),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _hideHoliday(h);
              },
              child: Text(l.calendarHolidayHide),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(l.calendarHolidayHide),
              onTap: () {
                Navigator.pop(ctx);
                _hideHoliday(h);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Hides (source, name) in every year, with Undo. The snackbar outlives
  /// this screen, so it uses the captured container, not ref.
  void _hideHoliday(HolidayLine h) {
    final l = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final source = h.day.sourceId;
    final name = h.day.name;
    showUndoableAction(
      context,
      busyKey: ('holiday-hide', source, name),
      run: () => container.read(myHolidaysProvider.notifier).hide(source, name),
      undo: () =>
          container.read(myHolidaysProvider.notifier).unhide(source, name),
      done: l.calendarHolidayHidden(name),
      failed: l.calendarHolidayHideFailed(name),
      undone: l.calendarHolidayShown(name),
      undoFailed: l.calendarHolidayUndoFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isApple = Theme.of(context).platform == TargetPlatform.iOS;
    final async = ref.watch(calendarViewProvider);
    final denied = ref.watch(calendarPermissionDeniedProvider);
    final showLunar = ref.watch(showLunarProvider);
    final wide = MediaQuery.sizeOf(context).width >= kCalendarWideBreakpoint;

    final cloudUnavailable =
        async.hasError && isCalendarCloudApiUnavailable(async.error!);

    Widget body;
    if (async.hasError) {
      final e = async.error!;
      if (cloudUnavailable) {
        body = const CalendarCloudApiMessage();
      } else {
        // Type only: the error text can quote stored event data.
        debugPrint('Calendar failed to load (${e.runtimeType})');
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.calendarLoadFailed, textAlign: TextAlign.center),
          ),
        );
      }
    } else if (async.hasValue) {
      final data = async.requireValue;
      // Read only here: in the Cloud API unavailable state no holiday
      // provider is touched.
      final regions = ref.watch(holidayRegionsProvider);
      final shown = DateTime(data.month.year, data.month.month);
      final holidays = ref.watch(holidaysForMonthProvider(shown)).value;
      // The agenda day can lie outside the shown month; when its year is not
      // among the shown month's years, look it up in its own month.
      final dayHolidays =
          yearsToFetch(shown, DateTime.now()).contains(data.day.year)
          ? holidays
          : ref
                .watch(
                  holidaysForMonthProvider(
                    DateTime(data.day.year, data.day.month),
                  ),
                )
                .value;
      body = _content(data, wide, showLunar, holidays, dayHolidays, regions);
    } else {
      body = const Center(child: CircularProgressIndicator.adaptive());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.calendarTitle),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(selectedDayProvider.notifier).select(DateTime.now()),
            child: Text(l.calendarToday),
          ),
          if (isApple)
            HmmIconButton(
              icon: Icons.add,
              tooltip: l.calendarAddEvent,
              onPressed: _add,
            ),
          if (!cloudUnavailable)
            HmmIconButton(
              icon: adaptiveIcon(
                context,
                material: Icons.flag_outlined,
                apple: CupertinoIcons.flag,
              ),
              tooltip: l.calendarHolidays,
              onPressed: () => context.push('/calendar/holidays'),
            ),
          const HelpButton(helpId: HelpId.calendar),
        ],
      ),
      floatingActionButton: isApple
          ? null
          : FloatingActionButton(
              tooltip: l.calendarAddEvent,
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (denied) const PermissionBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _content(
    CalendarViewData data,
    bool wide,
    bool showLunar,
    HolidayIndex? holidays,
    HolidayIndex? dayHolidays,
    List<HolidayRegion> regions,
  ) {
    final l = AppLocalizations.of(context);
    final colors = holidayColors(regions);
    final countryOf = {for (final r in regions) r.sourceId: r.country};
    final holidayMarks = holidays == null
        ? null
        : holidayMarksFor(holidays, data.month, colors);
    final holidayLines = <HolidayLine>[
      if (dayHolidays != null)
        for (final h in dayHolidays.on(data.day))
          HolidayLine(
            flag: h.sourceId == kMyHolidaysSourceId
                ? null
                : flagEmoji(
                    countryOf[h.sourceId] ?? h.sourceId.split('-').first,
                  ),
            name: h.name,
            offDay: h.offDay,
            color: colors[h.sourceId] ?? kHolidayPalette.first,
            range: switch (dayHolidays.blockOf(h)) {
              null => null,
              (:final from, :final to) =>
                '${DateFormat.MMMd(l.localeName).format(from)} – '
                    '${DateFormat.MMMd(l.localeName).format(to)}',
            },
            day: h,
          ),
    ];
    Map<int, LunarCellLabel>? lunarLabels;
    if (showLunar) {
      lunarLabels = {};
      final days = DateTime(data.month.year, data.month.month + 1, 0).day;
      for (var d = 1; d <= days; d++) {
        final label = lunarCellLabel(
          DateTime(data.month.year, data.month.month, d),
        );
        if (label != null) lunarLabels[d] = label;
      }
    }
    final grid = MonthGrid(
      month: data.month,
      selected: data.day,
      today: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      eventDays: data.eventDays,
      lunarLabels: lunarLabels,
      holidayMarks: holidayMarks,
      onSelect: (d) => ref.read(selectedDayProvider.notifier).select(d),
      onPrevious: () => ref.read(visibleMonthProvider.notifier).shift(-1),
      onNext: () => ref.read(visibleMonthProvider.notifier).shift(1),
    );
    final agenda = AgendaList(
      day: data.day,
      items: data.agenda,
      unreadableIds: data.unreadableIds,
      lunarText: showLunar ? lunarFullText(data.day) : null,
      holidayLines: holidayLines,
      onHolidayTap: _holidayTap,
      onTap: _open,
      onDone: (i) => _mark(i, OccurrenceStatus.done),
      onSkip: (i) => _mark(i, OccurrenceStatus.skipped),
      onMenu: _menu,
    );
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 420,
            child: Padding(padding: const EdgeInsets.all(8), child: grid),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: agenda),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: grid,
        ),
        const Divider(height: 1),
        Expanded(child: agenda),
      ],
    );
  }
}
