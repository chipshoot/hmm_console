import 'package:flutter/material.dart';

import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../contact_labels.dart';

/// One editable (label, value) row. [label] is the STORED literal
/// (`mobile`), never its display text. [extraFields] and [rawKnownValues]
/// ride along untouched so a save here cannot drop keys a newer client wrote
/// or a stored value this version could not read.
class LabeledFieldEntry {
  const LabeledFieldEntry({
    required this.label,
    required this.value,
    this.extraFields = const {},
    this.rawKnownValues = const {},
  });

  final String label;
  final String value;
  final Map<String, dynamic> extraFields;
  final Map<String, dynamic> rawKnownValues;
}

class _Row {
  _Row(
    this.id,
    this.label,
    String value,
    this.extraFields, [
    this.rawKnownValues = const {},
  ]) : controller = TextEditingController(text: value);

  final int id;
  String label;
  final Map<String, dynamic> extraFields;
  final Map<String, dynamic> rawKnownValues;
  final TextEditingController controller;
}

/// A repeatable list of (label dropdown, value field, remove button) rows with
/// an add action. Used for phones, emails and addresses.
///
/// Owns its rows (and their controllers) and reports the whole list through
/// [onChanged] on every edit, add, remove or label change.
class LabeledFieldEditor extends StatefulWidget {
  const LabeledFieldEditor({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.valueLabel,
    required this.addLabel,
    required this.labels,
    required this.initial,
    required this.onChanged,
    this.keyboardType,
  });

  /// Prefix for widget keys: `<prefix>-label-<i>`, `<prefix>-value-<i>`.
  final String keyPrefix;
  final String title;
  final String valueLabel;
  final String addLabel;

  /// Stored labels offered by the picker (see `contact_labels.dart`).
  final List<String> labels;
  final List<LabeledFieldEntry> initial;
  final ValueChanged<List<LabeledFieldEntry>> onChanged;
  final TextInputType? keyboardType;

  @override
  State<LabeledFieldEditor> createState() => _LabeledFieldEditorState();
}

class _LabeledFieldEditorState extends State<LabeledFieldEditor> {
  late final List<_Row> _rows;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final e in widget.initial)
        _Row(_nextId++, e.label, e.value, e.extraFields, e.rawKnownValues),
    ];
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([
    for (final r in _rows)
      LabeledFieldEntry(
        label: r.label,
        value: r.controller.text,
        extraFields: r.extraFields,
        rawKnownValues: r.rawKnownValues,
      ),
  ]);

  void _add() {
    setState(() => _rows.add(_Row(_nextId++, widget.labels.first, '', {})));
    _emit();
  }

  void _remove(_Row row) {
    setState(() => _rows.remove(row));
    row.controller.dispose();
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(widget.title, style: theme.textTheme.titleSmall),
        ),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            key: ValueKey(_rows[i].id),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                DropdownButton<String>(
                  key: Key('${widget.keyPrefix}-label-$i'),
                  value: _rows[i].label,
                  underline: const SizedBox.shrink(),
                  items: [
                    // A stored label this version does not offer stays
                    // selectable, so opening and saving never rewrites it.
                    for (final s in {...widget.labels, _rows[i].label})
                      DropdownMenuItem(
                        value: s,
                        child: Text(fieldLabelText(s, l)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _rows[i].label = v);
                    _emit();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: Key('${widget.keyPrefix}-value-$i'),
                    controller: _rows[i].controller,
                    keyboardType: widget.keyboardType,
                    decoration: InputDecoration(labelText: widget.valueLabel),
                    onChanged: (_) => _emit(),
                  ),
                ),
                HmmIconButton(
                  icon: Icons.remove_circle_outline,
                  tooltip: l.contactRemoveFieldTooltip,
                  onPressed: () => _remove(_rows[i]),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(widget.addLabel),
            onPressed: _add,
          ),
        ),
      ],
    );
  }
}
