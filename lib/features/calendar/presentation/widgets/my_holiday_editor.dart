import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/util/uuid.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/holidays.dart';
import '../../states/holiday_settings_providers.dart';
import 'platform_date_time_pickers.dart';

/// Full-screen editor for one of the user's own holidays. Saves through
/// [myHolidaysProvider] and pops; [existing] null means a new entry.
class MyHolidayEditor extends ConsumerStatefulWidget {
  const MyHolidayEditor({super.key, this.existing});

  final MyHoliday? existing;

  @override
  ConsumerState<MyHolidayEditor> createState() => _MyHolidayEditorState();
}

class _MyHolidayEditorState extends ConsumerState<MyHolidayEditor> {
  late final TextEditingController _name;
  late MyHolidayKind _kind;
  late DateTime _start;
  DateTime? _end;
  late bool _offDay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _kind = e?.kind ?? MyHolidayKind.once;
    final now = DateTime.now();
    _start = e?.start ?? DateTime(now.year, now.month, now.day);
    _end = e?.end;
    _offDay = e?.offDay ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _apple => Theme.of(context).platform == TargetPlatform.iOS;

  bool get _endBeforeStart =>
      _kind == MyHolidayKind.once && _end != null && _end!.isBefore(_start);

  bool get _canSave =>
      !_saving && _name.text.trim().isNotEmpty && !_endBeforeStart;

  Future<void> _save() async {
    if (!_canSave) return;
    final notifier = ref.read(myHolidaysProvider.notifier);
    final holiday = MyHoliday(
      id: widget.existing?.id ?? generateUuid(),
      name: _name.text.trim(),
      kind: _kind,
      start: _start,
      end: _kind == MyHolidayKind.once ? _end : null,
      offDay: _offDay,
    );
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).calendarMyHolidaysSaveFailed;
    setState(() => _saving = true);
    try {
      await notifier.upsert(holiday);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _kindChoice(AppLocalizations l) {
    final options = {
      MyHolidayKind.once: l.calendarMyHolidaysOnce,
      MyHolidayKind.yearly: l.calendarMyHolidaysYearly,
    };
    void select(MyHolidayKind k) => setState(() => _kind = k);
    if (_apple) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<MyHolidayKind>(
          groupValue: _kind,
          children: {
            for (final e in options.entries)
              e.key: Padding(
                key: Key('my-holiday-kind-${e.key.name}'),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(e.value, maxLines: 1, overflow: TextOverflow.fade),
              ),
          },
          onValueChanged: (v) {
            if (v != null) select(v);
          },
        ),
      );
    }
    return Wrap(
      spacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            key: Key('my-holiday-kind-${e.key.name}'),
            label: Text(e.value),
            selected: e.key == _kind,
            onSelected: (_) => select(e.key),
          ),
      ],
    );
  }

  Future<void> _pickStart() async {
    final d = await showPlatformDatePicker(context, _start);
    if (d == null || !mounted) return;
    setState(() => _start = DateTime(d.year, d.month, d.day));
  }

  Future<void> _pickEnd() async {
    final d = await showPlatformDatePicker(context, _end ?? _start);
    if (d == null || !mounted) return;
    setState(() => _end = DateTime(d.year, d.month, d.day));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = DateFormat.yMMMd(l.localeName);
    final switchWidget = _apple
        ? CupertinoSwitch(
            key: const Key('my-holiday-dayoff'),
            value: _offDay,
            onChanged: (v) => setState(() => _offDay = v),
          )
        : Switch(
            key: const Key('my-holiday-dayoff'),
            value: _offDay,
            onChanged: (v) => setState(() => _offDay = v),
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l.calendarMyHolidaysAdd
              : l.calendarMyHolidaysEdit,
        ),
        actions: [
          TextButton(
            key: const Key('my-holiday-save'),
            onPressed: _canSave ? _save : null,
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('my-holiday-name'),
                controller: _name,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l.calendarMyHolidaysName,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: _kindChoice(l)),
            ListTile(
              key: const Key('my-holiday-start'),
              leading: const Icon(Icons.event),
              title: Text(l.calendarMyHolidaysStart),
              trailing: Text(fmt.format(_start)),
              onTap: _pickStart,
            ),
            if (_kind == MyHolidayKind.once)
              ListTile(
                key: const Key('my-holiday-end'),
                leading: const Icon(Icons.event_available_outlined),
                title: Text(l.calendarMyHolidaysEnd),
                trailing: _end == null
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fmt.format(_end!),
                            style: _endBeforeStart
                                ? TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  )
                                : null,
                          ),
                          HmmIconButton(
                            key: const Key('my-holiday-end-clear'),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).deleteButtonTooltip,
                            icon: Icons.clear,
                            onPressed: () => setState(() => _end = null),
                          ),
                        ],
                      ),
                onTap: _pickEnd,
              ),
            ListTile(
              leading: const Icon(Icons.beach_access_outlined),
              title: Text(l.calendarMyHolidaysDayOff),
              trailing: switchWidget,
              onTap: () => setState(() => _offDay = !_offDay),
            ),
          ],
        ),
      ),
    );
  }
}
