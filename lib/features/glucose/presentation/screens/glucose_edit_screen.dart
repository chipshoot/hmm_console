import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../calendar/presentation/widgets/platform_date_time_pickers.dart';
import '../../contract/glucose_errors.dart';
import '../../domain/glucose_reading.dart';
import '../../domain/glucose_units.dart';
import '../../states/glucose_edit_state.dart';
import '../widgets/glucose_cloud_api_message.dart';
import '../widgets/glucose_row.dart';
import '../widgets/glucose_unit_toggle.dart';

/// Log a new reading (`readingId` null) or edit an existing one. An
/// imported reading keeps its value and time; only tag and notes change.
class GlucoseEditScreen extends ConsumerStatefulWidget {
  const GlucoseEditScreen({super.key, this.readingId});

  /// Null for a new reading.
  final String? readingId;

  @override
  ConsumerState<GlucoseEditScreen> createState() => _GlucoseEditScreenState();
}

class _GlucoseEditScreenState extends ConsumerState<GlucoseEditScreen> {
  final _value = TextEditingController();
  final _notes = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  GlucoseEditNotifier get _form =>
      ref.read(glucoseEditProvider(widget.readingId).notifier);

  @override
  void dispose() {
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isApple => Theme.of(context).platform == TargetPlatform.iOS;

  void _seed(GlucoseEditState s) {
    _seeded = true;
    final v = s.value;
    if (v != null && !s.isImported) {
      _value.text = v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    }
    _notes.text = s.notes;
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
      debugPrint('glucoseEdit: save failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.glucoseSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAt(DateTime current, {required bool time}) async {
    final picked = await (time
        ? showPlatformTimePicker(context, current)
        : showPlatformDatePicker(context, current));
    if (!mounted || picked == null) return;
    _form.setAt(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(glucoseEditProvider(widget.readingId));
    final s = async.value;
    if (s != null && !_seeded) _seed(s);

    Widget body;
    if (s != null) {
      body = _formBody(s);
    } else if (async.hasError) {
      if (isGlucoseCloudApiUnavailable(async.error!)) {
        body = const GlucoseCloudApiMessage();
      } else {
        // Type only: the error text can quote stored data.
        debugPrint('glucoseEdit: load failed (${async.error.runtimeType})');
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
        title: Text(
          widget.readingId == null ? l.glucoseNewTitle : l.glucoseEditTitle,
        ),
        actions: [
          if (s != null)
            TextButton(
              key: const Key('glucose-save'),
              onPressed: s.canSave && !_saving ? _save : null,
              child: Text(l.glucoseSave),
            ),
          const HelpButton(helpId: HelpId.glucoseEdit),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _formBody(GlucoseEditState s) {
    final l = AppLocalizations.of(context);
    final original = s.original;
    final imported = s.isImported;
    final bounds = glucoseTypedBounds(s.unit);
    final sourceName = original?.appleHealth?.sourceName;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (imported)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              key: const Key('glucose-from-health'),
              sourceName == null || sourceName.isEmpty
                  ? l.glucoseFromHealth
                  : l.glucoseFromHealthSource(sourceName),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        _label(Icons.bloodtype_outlined, l.glucoseValueLabel),
        if (imported)
          ListTile(
            key: const Key('glucose-value-readonly'),
            title: Text(original!.glucose.display(original.glucose.unit)),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const Key('glucose-value'),
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: l.glucoseValueLabel,
                suffixText: s.unit.wire,
                border: const OutlineInputBorder(),
                errorText: s.valueOutOfRange
                    ? l.glucoseValueOutOfRange(
                        '${bounds.min}',
                        '${bounds.max}',
                        s.unit.wire,
                      )
                    : null,
              ),
              onChanged: _form.setValueText,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: glucoseUnitToggle(
              apple: _isApple,
              unit: s.unit,
              onChanged: _form.setUnit,
            ),
          ),
        ],
        const Divider(),
        _timeRow(s, readOnly: imported),
        const Divider(),
        _label(Icons.label_outline, l.glucoseTagLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in GlucoseContext.values)
                      ChoiceChip(
                        key: Key('glucose-tag-${c.wire}'),
                        label: Text(glucoseContextLabel(c, l)),
                        selected: s.context == c,
                        onSelected: (on) => _form.setContext(on ? c : null),
                      ),
                  ],
                ),
              ),
              if (s.context != null)
                HmmIconButton(
                  icon: Icons.close,
                  tooltip: l.glucoseTagClear,
                  onPressed: () => _form.setContext(null),
                ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const Key('glucose-notes'),
            controller: _notes,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.glucoseNotesLabel,
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

  Widget _timeRow(GlucoseEditState s, {required bool readOnly}) {
    final l = AppLocalizations.of(context);
    String fmt(DateFormat Function(String) f, String fallback) {
      try {
        return f(l.localeName).format(s.at);
      } catch (_) {
        // Locale data unavailable: ISO still reads.
        return fallback;
      }
    }

    final iso = s.at.toIso8601String();
    final date = fmt(DateFormat.MMMEd, iso.substring(0, 10));
    final time = fmt(DateFormat.jm, iso.substring(11, 16));
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: Text(l.glucoseTimeLabel),
      trailing: readOnly
          ? Text(key: const Key('glucose-time-readonly'), '$date  $time')
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: const Key('glucose-date'),
                  onPressed: () => _pickAt(s.at, time: false),
                  child: Text(date),
                ),
                TextButton(
                  key: const Key('glucose-time'),
                  onPressed: () => _pickAt(s.at, time: true),
                  child: Text(time),
                ),
              ],
            ),
    );
  }
}
