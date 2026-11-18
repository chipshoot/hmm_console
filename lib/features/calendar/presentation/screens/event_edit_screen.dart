import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../contract/calendar_errors.dart';
import '../../contract/i_calendar_repository.dart';
import '../../domain/calendar_event.dart';
import '../../notifications/local_reminder_scheduler.dart';
import '../../notifications/reminder_sync.dart';
import '../../states/calendar_providers.dart';
import '../../states/event_edit_state.dart';
import '../../states/remind_on_device_provider.dart';
import '../widgets/calendar_cloud_api_message.dart';
import '../widgets/edit_scope_dialog.dart';
import '../widgets/platform_date_time_pickers.dart';
import '../widgets/reminder_list_editor.dart';
import '../widgets/repeat_picker.dart';
import '../widgets/unreadable_event_tile.dart';

enum _Load { loading, ready, notFound, unreadable, cloudApi, failed }

/// Creates an event ([eventId] null, prefilled on [day]) or edits one. For a
/// repeating event opened at an occurrence ([at] = its `originalStart`
/// wireKey) the form shows that occurrence, and saving asks whether the
/// change is for this occurrence or all of them.
class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({super.key, this.eventId, this.at, this.day});

  final String? eventId;
  final String? at;
  final DateTime? day;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  var _load = _Load.loading;
  CalendarEvent? _event;
  OccurrenceRef? _at;
  EventForm? _initial;
  late EventForm _form;
  var _saving = false;
  var _showErrors = false;
  final _title = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Starts loading the stored "Remind on this device" choice early.
    ref.read(remindOnDeviceProvider);
    final ICalendarRepository repo;
    try {
      repo = ref.read(calendarRepositoryProvider);
    } catch (e) {
      _load = isCalendarCloudApiUnavailable(e) ? _Load.cloudApi : _Load.failed;
      return;
    }
    final id = widget.eventId;
    if (id == null) {
      _setForm(EventForm.newOn(widget.day ?? DateTime.now(), DateTime.now()));
      _load = _Load.ready;
    } else {
      _read(repo, id);
    }
  }

  void _setForm(EventForm f) {
    _form = f;
    _title.text = f.title;
    _notes.text = f.notes;
  }

  Future<void> _read(ICalendarRepository repo, String id) async {
    _Load next;
    try {
      final e = await repo.getEvent(id);
      if (e == null) {
        next = _Load.notFound;
      } else {
        _event = e;
        _at = resolveOccurrence(e, widget.at);
        _initial = EventForm.fromEvent(e, at: _at);
        _setForm(_initial!);
        next = _Load.ready;
      }
    } on CalendarEventUnreadable {
      next = _Load.unreadable;
    } catch (e) {
      // Type only: the error text can quote stored event data.
      debugPrint('Calendar event failed to load (${e.runtimeType})');
      next = _Load.failed;
    }
    if (mounted) setState(() => _load = next);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _update(EventForm f) => setState(() => _form = f);

  /// True when a field only the series has (repeat, reminders, notes, the
  /// length: an override has no end of its own) was changed: such an edit can
  /// only apply to all occurrences.
  bool _seriesFieldsChanged(EventForm f, EventForm initial) {
    if (f.rrule != initial.rrule || f.notes.trim() != initial.notes.trim()) {
      return true;
    }
    if (wallDiff(f.end, f.start) != wallDiff(initial.end, initial.start)) {
      return true;
    }
    if (f.reminders.length != initial.reminders.length) return true;
    for (var i = 0; i < f.reminders.length; i++) {
      if (f.reminders[i] != initial.reminders[i]) return true;
    }
    return false;
  }

  Future<void> _save() async {
    final f = _form;
    if (!f.canSave) {
      setState(() => _showErrors = true);
      return;
    }
    final l = AppLocalizations.of(context);
    // Everything needed after an await is read now.
    final repo = ref.read(calendarRepositoryProvider);
    final remind = ref.read(remindOnDeviceProvider);
    final scheduler = ref.read(reminderSchedulerProvider);
    final denied = ref.read(calendarPermissionDeniedProvider.notifier);
    final sync = ref.read(reminderSyncProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final base = _event;
    final at = _at;
    final initial = _initial;

    var scope = EditScope.all;
    if (base != null &&
        at != null &&
        initial != null &&
        isRepeating(base) &&
        !_seriesFieldsChanged(f, initial)) {
      final s = await showEditScopeDialog(context);
      if (s == null || !mounted) return;
      scope = s;
    }

    setState(() => _saving = true);
    final bool hasDeviceReminder;
    try {
      if (scope == EditScope.thisOccurrence) {
        final o = buildOccurrenceOverride(base!, at!, initial!, f);
        if (o != null) await repo.setOccurrence(base.id, o);
        hasDeviceReminder = base.reminders.any(
          (r) => r.channel == ReminderChannel.device,
        );
      } else {
        await repo.saveEvent(
          buildEvent(f, base: base, initial: initial, now: DateTime.now()),
        );
        hasDeviceReminder = f.hasDeviceReminder;
      }
    } catch (e) {
      debugPrint('Calendar event failed to save (${e.runtimeType})');
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.calendarSaveFailed)));
      return;
    }
    // ReminderSync picks the change up through repo.changes().
    try {
      await askReminderPermissionIfFirst(
        remindOnDevice: remind,
        hasDeviceReminder: hasDeviceReminder,
        scheduler: scheduler,
        denied: denied,
        afterAsk: sync.trigger,
      );
    } catch (e) {
      debugPrint('Notification permission request failed (${e.runtimeType})');
    }
    if (navigator.mounted && navigator.canPop()) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickStart({required bool time}) async {
    final picked = await (time
        ? showPlatformTimePicker(context, _form.start)
        : showPlatformDatePicker(context, _form.start));
    if (picked == null || !mounted) return;
    // The end moves with the start, keeping the length.
    final length = wallDiff(_form.end, _form.start);
    _update(
      _form.copyWith(
        start: picked,
        end: wallAdd(picked, length.isNegative ? Duration.zero : length),
      ),
    );
  }

  Future<void> _pickEnd({required bool time}) async {
    final picked = await (time
        ? showPlatformTimePicker(context, _form.end)
        : showPlatformDatePicker(context, _form.end));
    if (picked == null || !mounted) return;
    _update(_form.copyWith(end: picked));
  }

  void _setAllDay(bool on) {
    final f = _form;
    if (on == f.allDay) return;
    if (on) {
      _update(
        f.copyWith(
          allDay: true,
          start: dateOnly(f.start),
          end: dateOnly(f.end),
        ),
      );
    } else {
      final start = DateTime(f.start.year, f.start.month, f.start.day, 9);
      final days = dateOnly(f.end).difference(dateOnly(f.start)).inDays;
      _update(
        f.copyWith(
          allDay: false,
          start: start,
          end: wallAdd(start, Duration(days: days < 0 ? 0 : days, hours: 1)),
        ),
      );
    }
  }

  Widget _timeRow(
    BuildContext context, {
    required String label,
    required DateTime value,
    required String keyPrefix,
    required VoidCallback onDate,
    required VoidCallback onTime,
  }) {
    final l = AppLocalizations.of(context);
    return ListTile(
      title: Text(label),
      trailing: Wrap(
        spacing: 4,
        children: [
          TextButton(
            key: Key('$keyPrefix-date'),
            onPressed: onDate,
            child: Text(
              DateFormat.yMMMEd(l.localeName).format(value),
              semanticsLabel:
                  '${l.calendarPickDate}: '
                  '${DateFormat.yMMMEd(l.localeName).format(value)}',
            ),
          ),
          if (!_form.allDay)
            TextButton(
              key: Key('$keyPrefix-time'),
              onPressed: onTime,
              child: Text(
                DateFormat.jm(l.localeName).format(value),
                semanticsLabel:
                    '${l.calendarPickTime}: '
                    '${DateFormat.jm(l.localeName).format(value)}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _formBody(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = _form;
    final error = Theme.of(context).colorScheme.error;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: const Key('calendar-edit-title'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.calendarTitleLabel,
              border: const OutlineInputBorder(),
              errorText: _showErrors && f.titleMissing
                  ? l.calendarTitleRequired
                  : null,
            ),
            onChanged: (v) => _update(_form.copyWith(title: v)),
          ),
        ),
        SwitchListTile.adaptive(
          key: const Key('calendar-edit-allday'),
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: Text(l.calendarAllDay),
          value: f.allDay,
          onChanged: _setAllDay,
        ),
        _timeRow(
          context,
          label: l.calendarStartLabel,
          value: f.start,
          keyPrefix: 'calendar-edit-start',
          onDate: () => _pickStart(time: false),
          onTime: () => _pickStart(time: true),
        ),
        _timeRow(
          context,
          label: l.calendarEndLabel,
          value: f.end,
          keyPrefix: 'calendar-edit-end',
          onDate: () => _pickEnd(time: false),
          onTime: () => _pickEnd(time: true),
        ),
        if (f.endBeforeStart)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l.calendarEndBeforeStart,
              style: TextStyle(color: error),
            ),
          ),
        const Divider(),
        _sectionLabel(context, l.calendarRepeatLabel),
        RepeatPicker(form: f, onChanged: _update),
        const Divider(),
        _sectionLabel(context, l.calendarRemindersLabel),
        ReminderListEditor(
          reminders: f.reminders,
          onChanged: (r) => _update(_form.copyWith(reminders: r)),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const Key('calendar-edit-notes'),
            controller: _notes,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.calendarNotesLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _update(_form.copyWith(notes: v)),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = switch (_load) {
      _Load.loading => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
      _Load.cloudApi => const CalendarCloudApiMessage(),
      _Load.notFound => _message(
        l.calendarEventNotFound,
        l.calendarEventNotFoundHint,
      ),
      _Load.unreadable => UnreadableEventTile(eventId: widget.eventId ?? ''),
      _Load.failed => _message(l.calendarEventLoadFailed),
      _Load.ready => _formBody(context),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.eventId == null ? l.calendarNewEvent : l.calendarEditEvent,
        ),
        actions: [
          if (_load == _Load.ready)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(l.calendarSave),
            ),
          const HelpButton(helpId: HelpId.calendarEventEdit),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}
