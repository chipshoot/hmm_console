import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../contract/calendar_errors.dart';
import '../../domain/calendar_event.dart';
import '../../states/calendar_providers.dart';
import '../../states/calendar_view_state.dart';
import '../../states/remind_on_device_provider.dart';
import '../widgets/agenda_list.dart';
import '../widgets/calendar_cloud_api_message.dart';
import '../widgets/month_grid.dart';

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

  Future<_RowAction?> _pickAction() {
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
        ),
      ),
    );
  }

  Future<void> _menu(AgendaItem i) async {
    final action = await _pickAction();
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
          done: l.calendarDeleteOne,
          failed: l.calendarDeleteOneFailed,
          undone: l.calendarDeleteOneUndone,
        );
      case _RowAction.deleteSeries:
        await _undoable(
          i,
          change: () => repo.deleteEvent(i.event.id),
          done: l.calendarDeleteOne,
          failed: l.calendarDeleteOneFailed,
          undone: l.calendarDeleteOneUndone,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isApple = Theme.of(context).platform == TargetPlatform.iOS;
    final async = ref.watch(calendarViewProvider);
    final denied = ref.watch(calendarPermissionDeniedProvider);
    final wide = MediaQuery.sizeOf(context).width >= kCalendarWideBreakpoint;

    Widget body;
    if (async.hasError) {
      final e = async.error!;
      if (isCalendarCloudApiUnavailable(e)) {
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
      body = _content(async.requireValue, wide);
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
          if (denied)
            MaterialBanner(
              content: Text(l.calendarPermissionBanner),
              leading: const Icon(Icons.notifications_off_outlined),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _content(CalendarViewData data, bool wide) {
    final grid = MonthGrid(
      month: data.month,
      selected: data.day,
      today: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      eventDays: data.eventDays,
      onSelect: (d) => ref.read(selectedDayProvider.notifier).select(d),
      onPrevious: () => ref.read(visibleMonthProvider.notifier).shift(-1),
      onNext: () => ref.read(visibleMonthProvider.notifier).shift(1),
    );
    final agenda = AgendaList(
      day: data.day,
      items: data.agenda,
      unreadableIds: data.unreadableIds,
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
