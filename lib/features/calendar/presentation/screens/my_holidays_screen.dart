import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/holidays.dart';
import '../../states/holiday_settings_providers.dart';
import '../widgets/my_holiday_editor.dart';

bool _isApple(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// The user's own holidays (add, edit, swipe-delete with undo) and the
/// downloaded holidays they hid (Show again).
class MyHolidaysScreen extends ConsumerWidget {
  const MyHolidaysScreen({super.key});

  void _open(BuildContext context, [MyHoliday? existing]) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => MyHolidayEditor(existing: existing),
        ),
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, MyHoliday h) {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(myHolidaysProvider.notifier);
    final previous = ref.read(myHolidaysProvider);
    unawaited(
      showUndoableAction(
        context,
        run: () => notifier.delete(h.id),
        undo: () => notifier.restore(previous),
        done: l.calendarMyHolidaysDeleted(h.name),
        failed: l.calendarMyHolidaysDeleteFailed(h.name),
        undone: l.calendarMyHolidaysRestored(h.name),
        undoFailed: l.calendarHolidayUndoFailed,
        busyKey: ('my-holiday-delete', h.id),
      ),
    );
  }

  void _unhide(
    BuildContext context,
    WidgetRef ref,
    HiddenHoliday h,
    String name,
  ) {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(myHolidaysProvider.notifier);
    unawaited(
      showUndoableAction(
        context,
        run: () => notifier.unhide(h.source, h.name),
        undo: () => notifier.hide(h.source, h.name),
        done: l.calendarHolidayShown(name),
        failed: l.calendarHolidayShowFailed(name),
        undone: l.calendarHolidayHidden(name),
        undoFailed: l.calendarHolidayUndoFailed,
        busyKey: ('my-holiday-unhide', h.source, h.name),
      ),
    );
  }

  String _when(MyHoliday h, AppLocalizations l) {
    if (h.kind == MyHolidayKind.yearly) {
      return '${DateFormat.MMMd(l.localeName).format(h.start)}'
          ' · ${l.calendarMyHolidaysEveryYear}';
    }
    final f = DateFormat.yMMMd(l.localeName);
    final end = h.end;
    if (end == null || end == h.start) return f.format(h.start);
    return '${f.format(h.start)} – ${f.format(end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final apple = _isApple(context);
    final data = ref.watch(myHolidaysProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.calendarHolidaysMine),
        actions: [
          if (apple)
            HmmIconButton(
              icon: Icons.add,
              tooltip: l.calendarMyHolidaysAdd,
              onPressed: () => _open(context),
            ),
          const HelpButton(helpId: HelpId.calendarMyHolidays),
        ],
      ),
      floatingActionButton: apple
          ? null
          : FloatingActionButton(
              tooltip: l.calendarMyHolidaysAdd,
              onPressed: () => _open(context),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            for (final h in data.entries)
              Dismissible(
                key: Key('my-holiday-${h.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                ),
                onDismissed: (_) => _delete(context, ref, h),
                child: ListTile(
                  tileColor: Theme.of(context).scaffoldBackgroundColor,
                  leading: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: kMyHolidaysColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(h.name),
                  subtitle: Text(
                    '${_when(h, l)} · '
                    '${h.offDay ? l.calendarHolidayDayOff : l.calendarHolidayWorkday}',
                  ),
                  onTap: () => _open(context, h),
                ),
              ),
            if (data.hidden.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  l.calendarMyHolidaysHiddenSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final h in data.hidden)
                ListTile(
                  key: Key('hidden-holiday-${h.source}-${h.name}'),
                  title: Text(
                    '${flagEmoji(h.source.split('-').first)}  ${h.name}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _unhide(context, ref, h, h.name),
                    child: Text(l.calendarMyHolidaysShowAgain),
                  ),
                ),
            ],
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}
