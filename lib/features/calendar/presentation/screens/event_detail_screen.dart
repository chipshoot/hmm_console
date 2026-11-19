import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
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
import '../../contract/i_calendar_repository.dart';
import '../../domain/calendar_event.dart';
import '../../domain/event_time.dart';
import '../../states/calendar_providers.dart';
import '../../states/event_edit_state.dart';
import '../widgets/calendar_cloud_api_message.dart';
import '../widgets/reminder_list_editor.dart' show reminderLabel;
import '../widgets/repeat_picker.dart' show describeRuleText;
import '../widgets/unreadable_event_tile.dart';

enum _Delete { one, following, series }

/// "Diabetes" for `diabetes`; an unknown subsystem shows its own name.
String subsystemLabel(String subsystem, AppLocalizations l) =>
    switch (subsystem) {
      'diabetes' => l.calendarSubsystemDiabetes,
      _ =>
        subsystem.isEmpty
            ? subsystem
            : subsystem[0].toUpperCase() + subsystem.substring(1),
    };

Object _unwrap(Object e) {
  var x = e;
  while (x is ProviderException) {
    x = x.exception;
  }
  return x;
}

/// One event: title, when, repeat in words, reminders, notes, the owning
/// subsystem, and for a repeating event opened at an occurrence ([at]) that
/// occurrence with Done / Skip. A draft offers Approve.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId, this.at});

  final String eventId;
  final String? at;

  /// Runs [change] with Undo = saving [snapshot] (R-6). [repo] and [l] are
  /// read by the caller before any await; the snackbar outlives the screen.
  Future<void> _undoable(
    BuildContext context,
    ICalendarRepository repo,
    AppLocalizations l,
    CalendarEvent snapshot, {
    required Object busyKey,
    required Future<void> Function() change,
    required String done,
    required String failed,
    required String undone,
  }) {
    return showUndoableAction(
      context,
      busyKey: busyKey,
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

  Future<void> _mark(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent e,
    OccurrenceRef o,
    OccurrenceStatus s,
  ) {
    final l = AppLocalizations.of(context);
    final repo = ref.read(calendarRepositoryProvider);
    final isDone = s == OccurrenceStatus.done;
    return _undoable(
      context,
      repo,
      l,
      e,
      busyKey: ('calendar', e.id, o.originalStart.wireKey),
      change: () async {
        await repo.setOccurrence(e.id, o.withStatus(s));
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

  Future<_Delete?> _pickDelete(BuildContext context, bool occurrence) {
    final l = AppLocalizations.of(context);
    final options = occurrence
        ? {
            _Delete.one: l.calendarDeleteThis,
            _Delete.following: l.calendarDeleteFollowing,
            _Delete.series: l.calendarDeleteSeries,
          }
        : {_Delete.series: l.calendarDelete};
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return showCupertinoModalPopup<_Delete>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          actions: [
            for (final e in options.entries)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, e.key),
                child: Text(e.value),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
        ),
      );
    }
    return showModalBottomSheet<_Delete>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in options.entries)
              ListTile(
                leading: Icon(
                  e.key == _Delete.one
                      ? Icons.event_busy_outlined
                      : Icons.delete_outline,
                ),
                title: Text(e.value),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent e,
    OccurrenceRef? o,
  ) async {
    // Everything needed after the picker is read before awaiting it.
    final l = AppLocalizations.of(context);
    final repo = ref.read(calendarRepositoryProvider);
    final navigator = Navigator.of(context);
    final choice = await _pickDelete(context, o != null);
    // showUndoableAction needs a live context for its snackbar.
    if (choice == null || !context.mounted) return;

    Future<void> deleteSeries() async {
      var removed = false;
      await _undoable(
        context,
        repo,
        l,
        e,
        busyKey: ('calendar-delete', e.id),
        change: () async {
          await repo.deleteEvent(e.id);
          removed = true;
        },
        done: l.calendarSeriesDeleted,
        failed: l.calendarSeriesDeleteFailed,
        undone: l.calendarSeriesDeleteUndone,
      );
      if (removed && navigator.mounted && navigator.canPop()) navigator.pop();
    }

    switch (choice) {
      case _Delete.series:
        await deleteSeries();
      case _Delete.one:
        await _undoable(
          context,
          repo,
          l,
          e,
          busyKey: ('calendar', e.id, o!.originalStart.wireKey),
          change: () async {
            await repo.setOccurrence(
              e.id,
              o.withStatus(OccurrenceStatus.cancelled),
            );
          },
          done: l.calendarOccurrenceDeleted,
          failed: l.calendarOccurrenceDeleteFailed,
          undone: l.calendarOccurrenceDeleteUndone,
        );
      case _Delete.following:
        final truncated = truncateBefore(e, o!.originalStart);
        if (truncated == null) {
          // The first occurrence: "this and following" is the whole series.
          await deleteSeries();
          return;
        }
        await _undoable(
          context,
          repo,
          l,
          e,
          busyKey: ('calendar-following', e.id),
          change: () async {
            await repo.saveEvent(truncated);
          },
          done: l.calendarFollowingDeleted,
          failed: l.calendarFollowingDeleteFailed,
          undone: l.calendarFollowingDeleteUndone,
        );
    }
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent e,
  ) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(calendarRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.saveEvent(e.copyWith(draft: false));
    } catch (err) {
      debugPrint('Calendar approve failed (${err.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.calendarApproveFailed)));
    }
  }

  String _when(CalendarEvent e, OccurrenceRef? o, AppLocalizations l) {
    final seriesStart = wallOf(e.start);
    final start = o != null ? wallOf(o.effectiveStart) : seriesStart;
    final stored = e.end;
    DateTime? end;
    if (stored != null) {
      final length = wallDiff(wallOf(stored), seriesStart);
      if (!length.isNegative) end = wallAdd(start, length);
    }
    final date = DateFormat.yMMMEd(l.localeName);
    final time = DateFormat.jm(l.localeName);
    if (e.start is AllDay || o?.effectiveStart is AllDay) {
      final last = end != null && dateOnly(end).isAfter(dateOnly(start))
          ? ' – ${date.format(end)}'
          : '';
      return '${date.format(start)}$last · ${l.calendarAllDay}';
    }
    if (end == null) return '${date.format(start)} · ${time.format(start)}';
    if (dateOnly(end) == dateOnly(start)) {
      return '${date.format(start)} · '
          '${time.format(start)} – ${time.format(end)}';
    }
    return '${date.format(start)} ${time.format(start)} – '
        '${date.format(end)} ${time.format(end)}';
  }

  Widget _message(String title, [String? hint]) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );

  Widget _doneSkip(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent e,
    OccurrenceRef o,
  ) {
    final l = AppLocalizations.of(context);
    void done() => _mark(context, ref, e, o, OccurrenceStatus.done);
    void skip() => _mark(context, ref, e, o, OccurrenceStatus.skipped);
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return Row(
        children: [
          Expanded(
            child: CupertinoButton.filled(
              onPressed: done,
              child: Text(l.calendarMarkDone),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              onPressed: skip,
              child: Text(l.calendarSkip),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: done,
            icon: const Icon(Icons.check),
            label: Text(l.calendarMarkDone),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: skip,
            icon: const Icon(Icons.redo),
            label: Text(l.calendarSkip),
          ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent e,
    OccurrenceRef? o,
  ) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = o?.titleOverride ?? e.title;
    final status = o?.status;
    final statusText = switch (status) {
      OccurrenceStatus.done => l.calendarStatusDone,
      OccurrenceStatus.skipped => l.calendarStatusSkipped,
      OccurrenceStatus.cancelled => l.calendarStatusCancelled,
      _ => null,
    };
    final owner = e.owner;
    final notes = e.notes;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (e.draft)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.calendarDraftBanner)),
                  TextButton.icon(
                    onPressed: () => _approve(context, ref, e),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(l.calendarApprove),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text(_when(e, o, l)),
          subtitle: statusText == null ? null : Text(statusText),
        ),
        ListTile(
          leading: const Icon(Icons.repeat),
          title: Text(
            isRepeating(e)
                ? describeRuleText(e.rrule!, l)
                : l.calendarDoesNotRepeat,
          ),
        ),
        if (owner != null)
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: Text(
              l.calendarFromSubsystem(subsystemLabel(owner.subsystem, l)),
            ),
          ),
        if (e.reminders.isEmpty)
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(l.calendarNoReminders),
          ),
        for (final r in e.reminders)
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(reminderLabel(r.minutesBefore, l)),
          ),
        if (e.timeSensitive)
          ListTile(
            leading: const Icon(Icons.notification_important_outlined),
            title: Text(l.calendarTimeSensitive),
          ),
        if (notes != null && notes.trim().isNotEmpty)
          ListTile(leading: const Icon(Icons.notes), title: Text(notes)),
        if (o != null && status != OccurrenceStatus.cancelled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _doneSkip(context, ref, e, o),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(calendarEventProvider(eventId));
    final event = async.hasError ? null : async.value;
    final occurrence = event == null ? null : resolveOccurrence(event, at);

    Widget body;
    if (async.hasError) {
      final e = _unwrap(async.error!);
      if (isCalendarCloudApiUnavailable(e)) {
        body = const CalendarCloudApiMessage();
      } else if (e is CalendarEventUnreadable) {
        body = ListView(children: [UnreadableEventTile(eventId: eventId)]);
      } else {
        debugPrint('Calendar event failed to load (${e.runtimeType})');
        body = _message(l.calendarEventLoadFailed);
      }
    } else if (async.hasValue) {
      body = event == null
          ? _message(l.calendarEventNotFound, l.calendarEventNotFoundHint)
          : _content(context, ref, event, occurrence);
    } else {
      body = const Center(child: CircularProgressIndicator.adaptive());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.calendarEventTitle),
        actions: [
          if (event != null) ...[
            HmmIconButton(
              icon: adaptiveIcon(
                context,
                material: Icons.edit_outlined,
                apple: CupertinoIcons.pencil,
              ),
              tooltip: l.calendarEdit,
              onPressed: () => context.pushNamed(
                RouterNames.calendarEventEdit.name,
                pathParameters: {'id': event.id},
                queryParameters: {'at': ?at},
              ),
            ),
            HmmIconButton(
              icon: adaptiveIcon(
                context,
                material: Icons.more_vert,
                apple: CupertinoIcons.ellipsis_circle,
              ),
              tooltip: l.calendarMoreActions,
              onPressed: () => _delete(context, ref, event, occurrence),
            ),
          ],
          const HelpButton(helpId: HelpId.calendarEvent),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}
