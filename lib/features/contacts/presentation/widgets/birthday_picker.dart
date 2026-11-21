import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../calendar/domain/lunar.dart';
import '../../domain/entities/contact_birthday.dart';

/// What the birthday picker returns. A null result means cancelled.
sealed class BirthdayPickResult {
  const BirthdayPickResult();
}

class BirthdayPicked extends BirthdayPickResult {
  const BirthdayPicked(this.birthday);
  final ContactBirthday birthday;
}

class BirthdayCleared extends BirthdayPickResult {
  const BirthdayCleared();
}

bool _isApple(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// Gregorian or lunar birthday with an optional year: Cupertino wheels in a
/// bottom sheet on Apple platforms, a Material dialog with dropdowns
/// elsewhere. Null when cancelled; [BirthdayCleared] when Clear is tapped
/// (offered only when [initial] is set).
Future<BirthdayPickResult?> showBirthdayPicker(
  BuildContext context, {
  ContactBirthday? initial,
}) {
  if (_isApple(context)) {
    return showCupertinoModalPopup<BirthdayPickResult>(
      context: context,
      builder: (_) => _BirthdayShell(initial: initial, apple: true),
    );
  }
  return showDialog<BirthdayPickResult>(
    context: context,
    builder: (_) => _BirthdayShell(initial: initial, apple: false),
  );
}

int _daysIn(ContactBirthday b) => b.calendar == BirthdayCalendar.lunar
    ? 30
    : DateTime.utc(b.year ?? 2000, b.month + 1, 0).day;

int _minYear(BirthdayCalendar c) => c == BirthdayCalendar.lunar ? 1901 : 1900;

ContactBirthday _clamp(ContactBirthday b) {
  // The year is never altered: a stored year outside the wheel's range stays.
  return _with(b, day: b.day.clamp(1, _daysIn(b)));
}

ContactBirthday _with(
  ContactBirthday b, {
  BirthdayCalendar? calendar,
  int? month,
  int? day,
  bool? leap,
  Object? year = _keep,
}) {
  final cal = calendar ?? b.calendar;
  return ContactBirthday(
    calendar: cal,
    month: month ?? b.month,
    day: day ?? b.day,
    leap: cal == BirthdayCalendar.lunar ? (leap ?? b.leap) : false,
    year: identical(year, _keep) ? b.year : year as int?,
  );
}

const Object _keep = Object();

class _BirthdayShell extends StatefulWidget {
  const _BirthdayShell({required this.initial, required this.apple});
  final ContactBirthday? initial;
  final bool apple;

  @override
  State<_BirthdayShell> createState() => _BirthdayShellState();
}

class _BirthdayShellState extends State<_BirthdayShell> {
  late ContactBirthday _value = _clamp(
    widget.initial ??
        const ContactBirthday(
          calendar: BirthdayCalendar.gregorian,
          month: 1,
          day: 1,
        ),
  );

  void _pop(BirthdayPickResult? r) => Navigator.of(context).pop(r);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final form = _BirthdayForm(
      value: _value,
      apple: widget.apple,
      storedYear: widget.initial?.year,
      onChanged: (v) => setState(() => _value = _clamp(v)),
    );
    final hasInitial = widget.initial != null;
    if (widget.apple) {
      return Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CupertinoButton(
                      onPressed: () => _pop(null),
                      child: Text(l.commonCancel),
                    ),
                    if (hasInitial)
                      CupertinoButton(
                        onPressed: () => _pop(const BirthdayCleared()),
                        child: Text(
                          l.contactBirthdayClear,
                          style: const TextStyle(
                            color: CupertinoColors.destructiveRed,
                          ),
                        ),
                      ),
                    const Spacer(),
                    CupertinoButton(
                      onPressed: () => _pop(BirthdayPicked(_value)),
                      child: Text(l.calendarPickerDone),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: form,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(l.contactBirthday),
      content: SingleChildScrollView(child: form),
      actions: [
        TextButton(onPressed: () => _pop(null), child: Text(l.commonCancel)),
        if (hasInitial)
          TextButton(
            onPressed: () => _pop(const BirthdayCleared()),
            child: Text(l.contactBirthdayClear),
          ),
        FilledButton(
          onPressed: () => _pop(BirthdayPicked(_value)),
          child: Text(l.calendarPickerDone),
        ),
      ],
    );
  }
}

class _BirthdayForm extends StatelessWidget {
  const _BirthdayForm({
    required this.value,
    required this.apple,
    required this.storedYear,
    required this.onChanged,
  });

  /// The year the contact already had; kept selectable even outside the range.
  final int? storedYear;
  final ContactBirthday value;
  final bool apple;
  final ValueChanged<ContactBirthday> onChanged;

  bool get _lunar => value.calendar == BirthdayCalendar.lunar;

  String _monthLabel(BuildContext context, int m) {
    if (_lunar) return lunarMonthName(m);
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.MMMM(locale).format(DateTime(2000, m));
  }

  String _dayLabel(int d) => _lunar ? lunarDayName(d) : '$d';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now().year;
    final years = <int>{
      for (var y = now; y >= _minYear(value.calendar); y--) y,
      ?storedYear,
    }.toList()..sort((a, b) => b.compareTo(a));
    final calendarControl = apple
        ? SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<BirthdayCalendar>(
              groupValue: value.calendar,
              children: {
                BirthdayCalendar.gregorian: Padding(
                  key: const Key('birthday-cal-gregorian'),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(l.contactBirthdayGregorian),
                ),
                BirthdayCalendar.lunar: Padding(
                  key: const Key('birthday-cal-lunar'),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(l.contactBirthdayLunar),
                ),
              },
              onValueChanged: (c) {
                if (c != null) onChanged(_with(value, calendar: c));
              },
            ),
          )
        : SegmentedButton<BirthdayCalendar>(
            segments: [
              ButtonSegment(
                value: BirthdayCalendar.gregorian,
                label: Text(l.contactBirthdayGregorian),
              ),
              ButtonSegment(
                value: BirthdayCalendar.lunar,
                label: Text(l.contactBirthdayLunar),
              ),
            ],
            selected: {value.calendar},
            onSelectionChanged: (s) =>
                onChanged(_with(value, calendar: s.first)),
          );

    final leap = _lunar
        ? (apple
              ? Row(
                  children: [
                    Expanded(child: Text(l.contactBirthdayLeapMonth)),
                    CupertinoSwitch(
                      key: const Key('birthday-leap'),
                      value: value.leap,
                      onChanged: (v) => onChanged(_with(value, leap: v)),
                    ),
                  ],
                )
              : SwitchListTile(
                  key: const Key('birthday-leap'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.contactBirthdayLeapMonth),
                  value: value.leap,
                  onChanged: (v) => onChanged(_with(value, leap: v)),
                ))
        : null;

    final days = _daysIn(value);
    final Widget fields;
    if (apple) {
      fields = SizedBox(
        height: 180,
        child: Row(
          children: [
            Expanded(
              child: _Wheel(
                key: Key('birthday-month-${value.calendar.name}'),
                count: 12,
                selected: value.month - 1,
                label: (i) => _monthLabel(context, i + 1),
                onChanged: (i) => onChanged(_with(value, month: i + 1)),
              ),
            ),
            Expanded(
              child: _Wheel(
                key: Key('birthday-day-${value.calendar.name}'),
                count: days,
                selected: value.day - 1,
                label: (i) => _dayLabel(i + 1),
                onChanged: (i) => onChanged(_with(value, day: i + 1)),
              ),
            ),
            Expanded(
              child: _Wheel(
                key: Key('birthday-year-${value.calendar.name}'),
                count: years.length + 1,
                selected: value.year == null
                    ? 0
                    : years.indexOf(value.year!) + 1,
                label: (i) =>
                    i == 0 ? l.contactBirthdayNoYear : '${years[i - 1]}',
                onChanged: (i) =>
                    onChanged(_with(value, year: i == 0 ? null : years[i - 1])),
              ),
            ),
          ],
        ),
      );
    } else {
      Widget drop<T>({
        required Key key,
        required T? current,
        required List<DropdownMenuItem<T>> items,
        required ValueChanged<T?> onSelected,
        String? label,
      }) => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            key: key,
            value: current,
            isExpanded: true,
            isDense: true,
            items: items,
            onChanged: onSelected,
          ),
        ),
      );
      fields = Column(
        children: [
          Row(
            children: [
              Expanded(
                child: drop<int>(
                  key: const Key('birthday-month-drop'),
                  current: value.month,
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text(_monthLabel(context, m)),
                      ),
                  ],
                  onSelected: (m) => onChanged(_with(value, month: m)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: drop<int>(
                  key: const Key('birthday-day-drop'),
                  current: value.day,
                  items: [
                    for (var d = 1; d <= days; d++)
                      DropdownMenuItem(value: d, child: Text(_dayLabel(d))),
                  ],
                  onSelected: (d) => onChanged(_with(value, day: d)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          drop<int?>(
            key: const Key('birthday-year-drop'),
            current: value.year,
            label: l.contactBirthdayYear,
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(l.contactBirthdayNoYear),
              ),
              for (final y in years)
                DropdownMenuItem<int?>(value: y, child: Text('$y')),
            ],
            onSelected: (y) => onChanged(_with(value, year: y)),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [calendarControl, const SizedBox(height: 8), ?leap, fields],
    );
  }
}

/// A single-column wheel that follows [selected] when the form clamps it.
class _Wheel extends StatefulWidget {
  const _Wheel({
    super.key,
    required this.count,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final int count;
  final int selected;
  final String Function(int index) label;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.selected);

  @override
  void didUpdateWidget(_Wheel old) {
    super.didUpdateWidget(old);
    if (_controller.hasClients && _controller.selectedItem != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToItem(widget.selected);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPicker(
    scrollController: _controller,
    itemExtent: 32,
    onSelectedItemChanged: widget.onChanged,
    children: [
      for (var i = 0; i < widget.count; i++)
        Center(child: Text(widget.label(i), maxLines: 1)),
    ],
  );
}
