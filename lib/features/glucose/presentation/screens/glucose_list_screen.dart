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
import '../../contract/glucose_errors.dart';
import '../../domain/glucose_range.dart';
import '../../domain/glucose_reading.dart';
import '../../domain/glucose_units.dart';
import '../../import/glucose_import_runner.dart';
import '../../import/glucose_importer.dart';
import '../../states/glucose_list_state.dart';
import '../../states/glucose_providers.dart';
import '../../states/glucose_settings_providers.dart';
import '../widgets/glucose_cloud_api_message.dart';
import '../widgets/glucose_row.dart';

enum _RowAction { edit, delete }

/// The glucose log: readings grouped by their recorded day.
class GlucoseListScreen extends ConsumerStatefulWidget {
  const GlucoseListScreen({super.key});

  @override
  ConsumerState<GlucoseListScreen> createState() => _GlucoseListScreenState();
}

class _GlucoseListScreenState extends ConsumerState<GlucoseListScreen> {
  bool _importing = false;

  /// Set by a manual run that found nothing; cleared by the next run.
  bool _nothingFound = false;

  bool get _isApple => Theme.of(context).platform == TargetPlatform.iOS;

  void _add() => context.pushNamed(RouterNames.glucoseCreate.name);

  void _setRange() => context.pushNamed(RouterNames.glucoseRange.name);

  void _open(GlucoseReading r) => context.pushNamed(
    RouterNames.glucoseEdit.name,
    pathParameters: {'id': r.id},
  );

  /// Soft delete with Undo = saving the snapshot taken first, which restores
  /// the same note under the same id.
  void _delete(GlucoseReading r) {
    final l = AppLocalizations.of(context);
    final repo = ref.read(glucoseRepositoryProvider);
    showUndoableAction(
      context,
      busyKey: ('glucose-delete', r.id),
      run: () => repo.deleteReading(r.id),
      undo: () async {
        await repo.saveReading(r);
      },
      done: l.glucoseDeleted,
      failed: l.glucoseDeleteFailed,
      undone: l.glucoseDeleteUndone,
      undoFailed: l.glucoseUndoFailed,
    );
  }

  /// Manual import. Results never block the list: a busy sync or any other
  /// error is a short message; a gate that blocks (null) shows nothing.
  Future<void> _import() async {
    if (_importing) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final runner = ref.read(glucoseImportRunnerProvider);
    setState(() {
      _importing = true;
      _nothingFound = false;
    });
    GlucoseImportResult? result;
    try {
      result = await runner.importNow();
    } catch (e) {
      debugPrint('Glucose import failed (${e.runtimeType})');
      result = GlucoseImportResult(error: e);
    }
    if (!mounted) return;
    setState(() {
      _importing = false;
      _nothingFound =
          result != null &&
          result.error == null &&
          result.added == 0 &&
          result.seen == 0;
    });
    if (result == null) {
      // The runner's gates held it back. The import controls only show on
      // iOS with import on, so in practice it waits for the first sync.
      messenger.showSnackBar(
        SnackBar(content: Text(l.glucoseImportWaitingForSync)),
      );
      return;
    }
    final error = result.error;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is GlucoseImportBusy
                ? l.glucoseImportBusy
                : l.glucoseImportFailed,
          ),
        ),
      );
    } else if (result.added > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.glucoseImported(result.added))),
      );
    }
  }

  Future<_RowAction?> _pickAction() {
    final l = AppLocalizations.of(context);
    if (_isApple) {
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

  Future<void> _menu(GlucoseReading r) async {
    final action = await _pickAction();
    if (!mounted || action == null) return;
    switch (action) {
      case _RowAction.edit:
        _open(r);
      case _RowAction.delete:
        _delete(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isApple = _isApple;
    final async = ref.watch(glucoseListProvider);
    final cloudUnavailable =
        async.hasError && isGlucoseCloudApiUnavailable(async.error!);
    final canImport = isApple && ref.watch(glucoseImportOnDeviceProvider);

    Widget body;
    if (async.hasValue) {
      body = _content(async.requireValue, canImport);
    } else if (async.hasError) {
      if (cloudUnavailable) {
        body = const GlucoseCloudApiMessage();
      } else {
        // Type only: the error text can quote stored data.
        debugPrint('Glucose list failed to load (${async.error.runtimeType})');
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.glucoseLoadFailed, textAlign: TextAlign.center),
          ),
        );
      }
    } else {
      body = const Center(child: CircularProgressIndicator.adaptive());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.glucoseTitle),
        actions: [
          if (canImport && !cloudUnavailable)
            HmmIconButton(
              icon: adaptiveIcon(
                context,
                material: Icons.sync,
                apple: CupertinoIcons.arrow_2_circlepath,
              ),
              tooltip: l.glucoseImportNow,
              onPressed: _importing ? null : _import,
            ),
          if (isApple && !cloudUnavailable)
            HmmIconButton(
              icon: adaptiveIcon(
                context,
                material: Icons.add,
                apple: CupertinoIcons.add,
              ),
              tooltip: l.glucoseLogAction,
              onPressed: _add,
            ),
          const HelpButton(helpId: HelpId.glucose),
        ],
      ),
      floatingActionButton: isApple || cloudUnavailable
          ? null
          : FloatingActionButton(
              tooltip: l.glucoseLogAction,
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
      body: SafeArea(top: false, child: body),
    );
  }

  String _dayLabel(DateTime date, DateTime today, AppLocalizations l) {
    if (date == today) return l.glucoseToday;
    if (date == today.subtract(const Duration(days: 1))) {
      return l.glucoseYesterday;
    }
    try {
      return DateFormat.MMMEd(l.localeName).format(date);
    } catch (_) {
      // Locale data unavailable: a plain ISO date still reads.
      return date.toIso8601String().substring(0, 10);
    }
  }

  String _num(num v, GlucoseUnit u) =>
      u == GlucoseUnit.mmoll ? v.toStringAsFixed(1) : v.round().toString();

  Widget _rangeLine(GlucoseRange? range, AppLocalizations l, ThemeData theme) {
    if (range == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(onPressed: _setRange, child: Text(l.glucoseSetRange)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        l.glucoseTargetRange(
          _num(range.low, range.unit),
          _num(range.high, range.unit),
          range.unit.wire,
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _importButton(AppLocalizations l) => _isApple
      ? CupertinoButton(
          onPressed: _importing ? null : _import,
          child: Text(l.glucoseImportFromHealth),
        )
      : OutlinedButton(
          onPressed: _importing ? null : _import,
          child: Text(l.glucoseImportFromHealth),
        );

  Widget _nothingFoundText(AppLocalizations l, ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      l.glucoseNothingFound,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _content(GlucoseListData data, bool canImport) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = ref.watch(glucoseRangeProvider);
    final unit = ref.watch(glucoseDisplayUnitProvider);
    if (data.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _rangeLine(range, l, theme),
          const SizedBox(height: 16),
          Text(l.glucoseEmpty, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: _isApple
                ? CupertinoButton.filled(
                    onPressed: _add,
                    child: Text(l.glucoseLogAction),
                  )
                : FilledButton(
                    onPressed: _add,
                    child: Text(l.glucoseLogAction),
                  ),
          ),
          if (canImport) ...[
            const SizedBox(height: 8),
            Center(child: _importButton(l)),
          ],
          if (_nothingFound) _nothingFoundText(l, theme),
        ],
      );
    }
    return ListView(
      children: [
        _rangeLine(range, l, theme),
        if (_nothingFound) _nothingFoundText(l, theme),
        for (final day in data.days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              _dayLabel(day.date, data.today, l),
              key: const Key('glucose-day-header'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final r in day.readings)
            GlucoseRow(
              key: ValueKey('glucose-${r.id}'),
              reading: r,
              unit: unit,
              range: range,
              onTap: () => _open(r),
              onMenu: () => _menu(r),
              onDelete: () => _delete(r),
            ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}
