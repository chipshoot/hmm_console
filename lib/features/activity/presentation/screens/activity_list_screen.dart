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
import '../../contract/activity_errors.dart';
import '../../domain/activity.dart';
import '../../domain/activity_kind.dart';
import '../../states/activity_kinds_provider.dart';
import '../../states/activity_list_state.dart';
import '../../states/activity_providers.dart';
import '../widgets/activity_cloud_api_message.dart';
import '../widgets/activity_row.dart';

enum _RowAction { edit, delete }

/// The activity log: area chips, then entries grouped by their recorded day.
class ActivityListScreen extends ConsumerStatefulWidget {
  const ActivityListScreen({super.key});

  @override
  ConsumerState<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends ConsumerState<ActivityListScreen> {
  /// Null = all areas.
  String? _area;

  void _add() => context.pushNamed(RouterNames.activityCreate.name);

  void _open(Activity a) => context.pushNamed(
    RouterNames.activityEdit.name,
    pathParameters: {'id': a.id},
  );

  /// Soft delete with Undo = saving the snapshot taken first, which restores
  /// the same note under the same id. Everything the snackbar needs is
  /// captured before any await.
  void _delete(Activity a) {
    final l = AppLocalizations.of(context);
    final repo = ref.read(activityRepositoryProvider);
    showUndoableAction(
      context,
      busyKey: ('activity-delete', a.id),
      run: () => repo.deleteActivity(a.id),
      undo: () async {
        await repo.saveActivity(a);
      },
      done: l.activityDeleted,
      failed: l.activityDeleteFailed,
      undone: l.activityDeleteUndone,
      undoFailed: l.activityUndoFailed,
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
              child: Text(l.commonEdit),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, _RowAction.delete),
              child: Text(l.commonDelete),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
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
              title: Text(l.commonEdit),
              onTap: () => Navigator.pop(ctx, _RowAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.commonDelete),
              onTap: () => Navigator.pop(ctx, _RowAction.delete),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(Activity a) async {
    final action = await _pickAction();
    if (!mounted || action == null) return;
    switch (action) {
      case _RowAction.edit:
        _open(a);
      case _RowAction.delete:
        _delete(a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isApple = Theme.of(context).platform == TargetPlatform.iOS;
    final async = ref.watch(activityListProvider(_area));
    final cloudUnavailable =
        async.hasError && isActivityCloudApiUnavailable(async.error!);

    Widget body;
    if (async.hasValue) {
      body = _content(async.requireValue);
    } else if (async.hasError) {
      if (cloudUnavailable) {
        body = const ActivityCloudApiMessage();
      } else {
        // Type only: the error text can quote stored data.
        debugPrint('Activity list failed to load (${async.error.runtimeType})');
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.activityLoadFailed, textAlign: TextAlign.center),
          ),
        );
      }
    } else {
      body = const Center(child: CircularProgressIndicator.adaptive());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.activityTitle),
        actions: [
          if (isApple && !cloudUnavailable)
            HmmIconButton(
              icon: adaptiveIcon(
                context,
                material: Icons.add,
                apple: CupertinoIcons.add,
              ),
              tooltip: l.activityLogAction,
              onPressed: _add,
            ),
          const HelpButton(helpId: HelpId.activity),
        ],
      ),
      floatingActionButton: isApple || cloudUnavailable
          ? null
          : FloatingActionButton(
              tooltip: l.activityLogAction,
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!cloudUnavailable)
              _chips(ref.watch(activityKindRegistryProvider)),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _chips(ActivityKindRegistry kinds) {
    final l = AppLocalizations.of(context);
    Widget chip(String? area, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _area == area,
        onSelected: (_) => setState(() => _area = area),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          chip(null, l.activityFilterAll),
          for (final area in kinds.areas)
            chip(area, activityAreaLabel(area, l)),
        ],
      ),
    );
  }

  String _dayLabel(DateTime date, DateTime today, AppLocalizations l) {
    if (date == today) return l.activityToday;
    if (date == today.subtract(const Duration(days: 1))) {
      return l.activityYesterday;
    }
    try {
      return DateFormat.MMMEd(l.localeName).format(date);
    } catch (_) {
      // Locale data unavailable: a plain ISO date still reads.
      return date.toIso8601String().substring(0, 10);
    }
  }

  Widget _loadEarlier(AppLocalizations l) => Center(
    child: TextButton(
      onPressed: () =>
          ref.read(activityListProvider(_area).notifier).loadEarlier(),
      child: Text(l.activityLoadEarlier),
    ),
  );

  Widget _content(ActivityListData data) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isApple = theme.platform == TargetPlatform.iOS;
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.activityEmpty, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (isApple)
                CupertinoButton.filled(
                  onPressed: _add,
                  child: Text(l.activityLogAction),
                )
              else
                FilledButton(onPressed: _add, child: Text(l.activityLogAction)),
              const SizedBox(height: 8),
              _loadEarlier(l),
            ],
          ),
        ),
      );
    }
    final kinds = ref.watch(activityKindRegistryProvider);
    return ListView(
      children: [
        for (final day in data.days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              _dayLabel(day.date, data.today, l),
              key: const Key('activity-day-header'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final a in day.entries)
            ActivityRow(
              key: ValueKey('activity-${a.id}'),
              activity: a,
              kinds: kinds,
              noteTitle: data.noteTitleFor(a),
              onTap: () => _open(a),
              onMenu: () => _menu(a),
              onDelete: () => _delete(a),
            ),
        ],
        _loadEarlier(l),
        const SizedBox(height: 80),
      ],
    );
  }
}
