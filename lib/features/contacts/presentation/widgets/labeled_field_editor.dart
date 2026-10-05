import 'package:flutter/material.dart';

import '../../../../core/util/calling_codes.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../contact_labels.dart';
import 'calling_code_picker.dart';

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
    this.code,
  ]) : initialValue = value,
       controller = TextEditingController(text: value);

  final int id;
  String label;
  final Map<String, dynamic> extraFields;
  final Map<String, dynamic> rawKnownValues;
  final TextEditingController controller;

  /// Selected country calling code (phone rows only); [controller] then holds
  /// just the national part.
  CallingCode? code;

  /// The stored string as loaded (or '' for a new row). An untouched row is
  /// written back as this, byte for byte, never re-composed.
  String initialValue;
  bool touched = false;

  /// The one stored string: `+<code> <national>` with a code, else the text
  /// as typed. A code with no digits after it is an empty value.
  String get value {
    if (!touched) return initialValue;
    final national = controller.text;
    final c = code;
    if (c == null) return national;
    final t = national.trim();
    return t.isEmpty ? '' : '+${c.code} $t';
  }
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
    this.countryCode = false,
    this.defaultRegion,
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

  /// Phone rows: show the country-code picker, split a leading `+<code>`
  /// into it, and filter the field to phone characters.
  final bool countryCode;

  /// ISO region (e.g. `CN`) that seeds the code of a NEW row.
  final String? defaultRegion;

  @override
  State<LabeledFieldEditor> createState() => _LabeledFieldEditorState();
}

class _LabeledFieldEditorState extends State<LabeledFieldEditor> {
  late final List<_Row> _rows;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _rows = [for (final e in widget.initial) _loadRow(e)];
  }

  _Row _loadRow(LabeledFieldEntry e) {
    final split = widget.countryCode ? splitInternationalNumber(e.value) : null;
    final row = _Row(
      _nextId++,
      e.label,
      split?.national ?? e.value,
      e.extraFields,
      e.rawKnownValues,
      split?.code,
    );
    row.initialValue = e.value;
    return row;
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
        value: r.value,
        extraFields: r.extraFields,
        rawKnownValues: r.rawKnownValues,
      ),
  ]);

  void _add() {
    setState(
      () => _rows.add(
        _Row(
          _nextId++,
          widget.labels.first,
          '',
          {},
          const {},
          widget.countryCode
              ? callingCodeForRegion(widget.defaultRegion)
              : null,
        ),
      ),
    );
    _emit();
  }

  void _onText(_Row row, String text) {
    row.touched = true;
    if (widget.countryCode) {
      final split = splitInternationalNumber(text);
      if (split != null) {
        // Keep a selected region that already has this code (CA for +1).
        if (row.code?.code != split.code.code) row.code = split.code;
        row.controller.value = TextEditingValue(
          text: split.national,
          selection: TextSelection.collapsed(offset: split.national.length),
        );
        setState(() {});
      }
    }
    _emit();
  }

  Future<void> _pickCode(_Row row) async {
    final choice = await showCallingCodePicker(context, selected: row.code);
    if (choice == null || !mounted) return;
    // Re-picking the current code changes nothing, so the stored value
    // must stay as loaded.
    if (choice.code == row.code) return;
    setState(() {
      row.code = choice.code;
      row.touched = true;
    });
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
                if (widget.countryCode)
                  Semantics(
                    label: l.contactCountryCodeTitle,
                    button: true,
                    child: TextButton(
                      key: Key('${widget.keyPrefix}-code-$i'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _pickCode(_rows[i]),
                      child: Text(
                        _rows[i].code?.label ?? l.contactCountryCodePlaceholder,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: Key('${widget.keyPrefix}-value-$i'),
                    controller: _rows[i].controller,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.countryCode
                        ? const [PhoneNumberFormatter()]
                        : null,
                    decoration: InputDecoration(labelText: widget.valueLabel),
                    onChanged: (v) => _onText(_rows[i], v),
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
