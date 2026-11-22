import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../calendar/presentation/widgets/platform_date_time_pickers.dart';
import '../../../notes/data/models/hmm_note.dart';
import '../../../notes/presentation/screens/note_picker.dart';
import '../../contract/activity_errors.dart';
import '../../data/local_activity_repository.dart';
import '../../domain/activity.dart';
import '../../domain/activity_kind.dart';
import '../../states/activity_edit_state.dart';
import '../../states/activity_kinds_provider.dart';
import '../../states/activity_providers.dart';
import '../distance_unit.dart';
import '../widgets/activity_cloud_api_message.dart';

/// Opens the note picker; returns the picked note or null.
typedef ActivityNotePicker = Future<HmmNote?> Function(BuildContext context);

/// The note picker the form uses. Tests replace it. Activity notes
/// themselves cannot be linked.
final activityNotePickerProvider = Provider<ActivityNotePicker>(
  (ref) =>
      (context) => showNotePicker(
        context,
        canPick: (_, catalogName) => catalogName != activityCatalogName,
      ),
);

/// Quick duration choices, in minutes.
const _quickDurations = [15, 30, 45, 60];

/// Log a new activity (`activityId` null) or edit an existing one.
class ActivityEditScreen extends ConsumerStatefulWidget {
  const ActivityEditScreen({super.key, this.activityId});

  /// Null for a new activity.
  final String? activityId;

  @override
  ConsumerState<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends ConsumerState<ActivityEditScreen> {
  final _custom = TextEditingController();
  final _distance = TextEditingController();
  final _notes = TextEditingController();
  bool _seeded = false;
  bool _customOpen = false;
  bool _saving = false;

  ActivityEditNotifier get _form =>
      ref.read(activityEditProvider(widget.activityId).notifier);

  @override
  void dispose() {
    _custom.dispose();
    _distance.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isApple => Theme.of(context).platform == TargetPlatform.iOS;

  void _seed(ActivityEditState s) {
    _seeded = true;
    final d = s.durationMinutes;
    if (d != null && !_quickDurations.contains(d)) {
      _customOpen = true;
      _custom.text = '$d';
    }
    final dist = s.distance;
    if (dist != null) {
      _distance.text = dist == dist.roundToDouble()
          ? dist.toStringAsFixed(0)
          : '$dist';
    }
    _notes.text = s.notes ?? '';
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await _form.save();
      if (!mounted) return;
      await Navigator.of(context).maybePop();
    } catch (e) {
      // Type only: the error text can quote stored data.
      debugPrint('activityEdit: save failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.activitySaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Soft delete with Undo (saving the loaded snapshot restores the same
  /// id), then leave. Everything the snackbar needs is captured first.
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
    Navigator.of(context).maybePop();
  }

  Future<void> _pickKind(ActivityEditState s) async {
    final apple = _isApple;
    final sheet = _KindSheet(
      kinds: ref.read(activityKindRegistryProvider),
      recent: s.recentKinds,
      selected: s.kindId,
      apple: apple,
    );
    final picked = await (apple
        ? showCupertinoModalPopup<String>(
            context: context,
            builder: (_) => sheet,
          )
        : showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (_) => sheet,
          ));
    if (!mounted || picked == null) return;
    _form.setKind(picked);
  }

  Future<void> _pickEnded(DateTime current, {required bool time}) async {
    final picked = await (time
        ? showPlatformTimePicker(context, current)
        : showPlatformDatePicker(context, current));
    if (!mounted || picked == null) return;
    _form.setEnded(picked);
  }

  Future<void> _pickNote() async {
    // Read the picker before the await; the picker never awaits the notes
    // list's data (that hangs while Notes is offstage).
    final picker = ref.read(activityNotePickerProvider);
    final note = await picker(context);
    if (!mounted || note == null) return;
    _form.setLink(note.uuid, note.subject.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(activityEditProvider(widget.activityId));
    final s = async.value;
    if (s != null && !_seeded) _seed(s);
    final cloudUnavailable =
        async.hasError && isActivityCloudApiUnavailable(async.error!);

    Widget body;
    if (s != null) {
      body = _formBody(s);
    } else if (async.hasError) {
      if (cloudUnavailable) {
        body = const ActivityCloudApiMessage();
      } else {
        // Type only: the error text can quote stored data.
        debugPrint('activityEdit: load failed (${async.error.runtimeType})');
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

    final original = s?.original;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.activityId == null ? l.activityNewTitle : l.activityEditTitle,
        ),
        actions: [
          if (s != null)
            TextButton(
              key: const Key('activity-save'),
              onPressed: s.canSave && !_saving ? _save : null,
              child: Text(l.activitySave),
            ),
          if (original != null)
            HmmIconButton(
              icon: Icons.delete_outline,
              tooltip: l.activityDelete,
              onPressed: () => _delete(original),
            ),
          const HelpButton(helpId: HelpId.activityEdit),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _formBody(ActivityEditState s) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kinds = ref.watch(activityKindRegistryProvider);
    final kind = s.kindId == null ? null : kinds.byId(s.kindId!);
    final error = theme.colorScheme.error;
    final unit =
        s.distanceUnit ??
        defaultDistanceUnit(View.of(context).platformDispatcher.locale);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (s.isUnknownKind)
          ListTile(
            key: const Key('activity-kind'),
            enabled: false,
            leading: const Icon(Icons.help_outline),
            title: Text(l.activityUnknownKind),
            subtitle: Text(s.kindId ?? ''),
          )
        else
          ListTile(
            key: const Key('activity-kind'),
            leading: Icon(kind?.icon ?? Icons.directions_walk),
            title: Text(l.activityKindLabel),
            subtitle: Text(kind?.label(l) ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickKind(s),
          ),
        const Divider(),
        _label(Icons.timer_outlined, l.activityDurationLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in _quickDurations)
                ChoiceChip(
                  label: Text(l.activityMinutes(m)),
                  selected: !_customOpen && s.durationMinutes == m,
                  onSelected: (_) {
                    setState(() => _customOpen = false);
                    _form.setDuration(m);
                  },
                ),
              ChoiceChip(
                key: const Key('activity-duration-custom'),
                label: Text(l.activityDurationCustom),
                selected: _customOpen,
                onSelected: (_) {
                  setState(() => _customOpen = true);
                  _form.setDuration(int.tryParse(_custom.text));
                },
              ),
            ],
          ),
        ),
        if (_customOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('activity-duration-minutes'),
              controller: _custom,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.activityDurationMinutes,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _form.setDuration(int.tryParse(v)),
            ),
          ),
        const Divider(),
        _endedRow(s),
        if (s.endedInFuture)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l.activityEndedInFuture,
              style: TextStyle(color: error),
            ),
          ),
        const Divider(),
        _label(Icons.speed, l.activityIntensityLabel),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _intensity(s),
        ),
        if (kind != null && kind.offersDistance)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('activity-distance'),
              controller: _distance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: l.activityDistanceLabel,
                suffixText: unit,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _form.setDistance(
                double.tryParse(v.trim().replaceAll(',', '.')),
                unit,
              ),
            ),
          ),
        const Divider(),
        ListTile(
          key: const Key('activity-link'),
          leading: const Icon(Icons.link),
          title: Text(l.activityLinkLabel),
          subtitle: Text(
            s.link == null
                ? l.activityLinkNone
                : s.linkRemoved
                ? l.activityLinkRemoved
                : (s.linkTitle?.isNotEmpty ?? false)
                ? s.linkTitle!
                : s.link!.noteUuid,
          ),
          trailing: s.link == null
              ? const Icon(Icons.chevron_right)
              : HmmIconButton(
                  icon: Icons.close,
                  tooltip: l.activityLinkClear,
                  onPressed: _form.clearLink,
                ),
          onTap: _pickNote,
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const Key('activity-notes'),
            controller: _notes,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.activityNotesLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: _form.setNotes,
          ),
        ),
      ],
    );
  }

  Widget _label(IconData icon, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );

  Widget _endedRow(ActivityEditState s) {
    final l = AppLocalizations.of(context);
    String fmt(DateFormat Function(String) f, String fallback) {
      try {
        return f(l.localeName).format(s.ended);
      } catch (_) {
        // Locale data unavailable: ISO still reads.
        return fallback;
      }
    }

    final iso = s.ended.toIso8601String();
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: Text(l.activityEndedLabel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: const Key('activity-ended-date'),
            onPressed: () => _pickEnded(s.ended, time: false),
            child: Text(fmt(DateFormat.MMMEd, iso.substring(0, 10))),
          ),
          TextButton(
            key: const Key('activity-ended-time'),
            onPressed: () => _pickEnded(s.ended, time: true),
            child: Text(fmt(DateFormat.jm, iso.substring(11, 16))),
          ),
        ],
      ),
    );
  }

  Widget _intensity(ActivityEditState s) {
    final l = AppLocalizations.of(context);
    String label(ActivityIntensity i) => switch (i) {
      ActivityIntensity.light => l.activityIntensityLight,
      ActivityIntensity.moderate => l.activityIntensityModerate,
      ActivityIntensity.vigorous => l.activityIntensityVigorous,
    };
    if (_isApple) {
      return CupertinoSlidingSegmentedControl<ActivityIntensity>(
        groupValue: s.intensity,
        children: {for (final i in ActivityIntensity.values) i: Text(label(i))},
        onValueChanged: _form.setIntensity,
      );
    }
    return SegmentedButton<ActivityIntensity>(
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      segments: [
        for (final i in ActivityIntensity.values)
          ButtonSegment(value: i, label: Text(label(i))),
      ],
      selected: {?s.intensity},
      onSelectionChanged: (v) => _form.setIntensity(v.isEmpty ? null : v.first),
    );
  }
}

/// The kind list: recent kinds first, then every kind grouped by area.
/// Pops with the picked kind id.
class _KindSheet extends StatelessWidget {
  const _KindSheet({
    required this.kinds,
    required this.recent,
    required this.selected,
    required this.apple,
  });

  final ActivityKindRegistry kinds;
  final List<String> recent;
  final String? selected;
  final bool apple;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final recentKinds = [for (final id in recent) ?kinds.byId(id)];
    final sections = <(String?, List<ActivityKind>)>[
      if (recentKinds.isNotEmpty) (null, recentKinds),
      for (final area in kinds.areas)
        (activityAreaLabel(area, l), kinds.inArea(area)),
    ];

    if (apple) {
      return CupertinoPopupSurface(
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: ListView(
              children: [
                for (final (header, list) in sections)
                  CupertinoListSection.insetGrouped(
                    header: header == null ? null : Text(header),
                    children: [
                      for (final k in list)
                        CupertinoListTile(
                          leading: Icon(k.icon),
                          title: Text(k.label(l)),
                          trailing: k.id == selected
                              ? const Icon(CupertinoIcons.check_mark)
                              : null,
                          onTap: () => Navigator.pop(context, k.id),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (i, (header, list)) in sections.indexed) ...[
              if (i > 0) const Divider(),
              if (header != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    header,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              for (final k in list)
                ListTile(
                  leading: Icon(k.icon),
                  title: Text(k.label(l)),
                  trailing: k.id == selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, k.id),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
