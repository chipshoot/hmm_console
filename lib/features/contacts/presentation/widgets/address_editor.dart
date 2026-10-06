import 'package:flutter/material.dart';

import '../../../../core/util/address_regions.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/address_format.dart';
import '../../domain/entities/contact_field.dart';
import '../contact_labels.dart';
import 'region_picker.dart';

/// Reports the addresses as they will be stored, and whether any EDITED
/// address has a non-blank postal code that breaks its country's format (the
/// save is refused while it does).
typedef AddressesChanged =
    void Function(List<ContactAddress> addresses, {required bool invalid});

class _Row {
  _Row(this.id, this.label, this.country, {this.original, ContactAddress? a})
    : street1 = TextEditingController(text: a?.street1 ?? ''),
      street2 = TextEditingController(text: a?.street2 ?? ''),
      city = TextEditingController(text: a?.city ?? ''),
      district = TextEditingController(text: a?.district ?? ''),
      postal = TextEditingController(text: a?.postalCode ?? ''),
      text = TextEditingController(
        text: a == null || a.isStructured ? '' : a.value,
      ),
      region = a?.region,
      touched = original == null;

  final int id;
  String label;

  /// `US` / `CA` / `CN`, or null for Other (free text).
  String? country;
  String? region;

  /// The address as loaded; null for a new row. An untouched row is emitted
  /// as this (label aside), never re-composed, so it saves byte-identical.
  final ContactAddress? original;
  bool touched;

  final TextEditingController street1;
  final TextEditingController street2;
  final TextEditingController city;
  final TextEditingController district;
  final TextEditingController postal;

  /// Other: the free text.
  final TextEditingController text;

  List<TextEditingController> get _all => [
    street1,
    street2,
    city,
    district,
    postal,
    text,
  ];

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }

  String? _v(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// The parts on screen for the current country (hidden fields' text is
  /// kept for switching back, but never stored).
  ContactAddress structured() {
    final cn = country == 'CN';
    final p = _v(postal);
    return ContactAddress(
      label: label,
      value: '',
      country: country,
      street1: _v(street1),
      street2: cn ? null : _v(street2),
      city: _v(city),
      district: cn ? _v(district) : null,
      region: region,
      postalCode: p == null ? null : normalizePostalCode(country, p),
    );
  }

  bool get postalInvalid =>
      touched && country != null && !isValidPostalCode(country, postal.text);

  ContactAddress emit() {
    final o = original;
    if (!touched && o != null) {
      return o.label == label ? o : o.copyWith(label: label);
    }
    final extra = o?.extraFields ?? const <String, dynamic>{};
    final raw = o?.rawKnownValues ?? const <String, dynamic>{};
    if (country == null) {
      return ContactAddress(
        label: label,
        value: text.text,
        extraFields: extra,
        rawKnownValues: raw,
      );
    }
    final s = structured();
    return withDerivedValue(
      ContactAddress(
        label: s.label,
        value: '',
        country: s.country,
        street1: s.street1,
        street2: s.street2,
        city: s.city,
        district: s.district,
        region: s.region,
        postalCode: s.postalCode,
        extraFields: extra,
        rawKnownValues: raw,
      ),
    );
  }
}

/// Repeatable address cards: label, country (United States / Canada / China /
/// Other) and that country's fields. A free-form address (no country, or one
/// this version does not know) opens as Other with its stored text; free
/// text is never parsed into parts.
class AddressEditor extends StatefulWidget {
  const AddressEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.defaultRegion,
  });

  final List<ContactAddress> initial;
  final AddressesChanged onChanged;

  /// ISO region (e.g. `CN`) that picks the country of a NEW address when it
  /// is one this editor formats; anything else starts as Other.
  final String? defaultRegion;

  @override
  State<AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<AddressEditor> {
  late final List<_Row> _rows;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final a in widget.initial)
        _Row(
          _nextId++,
          a.label,
          knownAddressCountries.contains(a.country) ? a.country : null,
          original: a,
          a: knownAddressCountries.contains(a.country)
              ? a
              : ContactAddress(label: a.label, value: a.value),
        ),
    ];
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([
    for (final r in _rows) r.emit(),
  ], invalid: _rows.any((r) => r.postalInvalid));

  void _add() {
    final region = widget.defaultRegion?.toUpperCase();
    setState(
      () => _rows.add(
        _Row(
          _nextId++,
          addressFieldLabels.first,
          knownAddressCountries.contains(region) ? region : null,
        ),
      ),
    );
    _emit();
  }

  void _remove(_Row row) {
    setState(() => _rows.remove(row));
    row.dispose();
    _emit();
  }

  void _edited(_Row row) {
    // Rebuilt so the postal error follows the text.
    setState(() => row.touched = true);
    _emit();
  }

  void _setCountry(_Row row, String? country) {
    if (country == row.country) return;
    setState(() {
      if (country == null) {
        // Keep what was entered, as text the user can now edit freely.
        final lines = formatMultiline(row.structured());
        if (lines.isNotEmpty) row.text.text = lines;
      }
      row.country = country;
      row.region = null;
      row.district.clear();
      row.touched = true;
    });
    _emit();
  }

  Future<void> _pickRegion(_Row row, String title) async {
    final country = row.country;
    if (country == null) return;
    final picked = await showRegionPicker(
      context,
      country: country,
      title: title,
      selected: row.region,
    );
    if (picked == null || !mounted || picked.code == row.region) return;
    setState(() {
      row.region = picked.code;
      row.touched = true;
    });
    _emit();
  }

  String _countryName(String? c, AppLocalizations l) => switch (c) {
    'US' => l.contactAddressCountryUS,
    'CA' => l.contactAddressCountryCA,
    'CN' => l.contactAddressCountryCN,
    _ => l.contactAddressCountryOther,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l.contactAddresses, style: theme.textTheme.titleSmall),
        ),
        for (var i = 0; i < _rows.length; i++) _card(context, l, i, _rows[i]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l.contactAddAddress),
            onPressed: _add,
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, AppLocalizations l, int i, _Row row) {
    return Card(
      key: Key('addresses-card-$i'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        key: ValueKey(row.id),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  key: Key('addresses-label-$i'),
                  value: row.label,
                  underline: const SizedBox.shrink(),
                  items: [
                    // A stored label this version does not offer stays
                    // selectable, so opening and saving never rewrites it.
                    for (final s in {...addressFieldLabels, row.label})
                      DropdownMenuItem(
                        value: s,
                        child: Text(fieldLabelText(s, l)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => row.label = v);
                    _emit();
                  },
                ),
                const Spacer(),
                HmmIconButton(
                  icon: Icons.remove_circle_outline,
                  tooltip: l.contactRemoveFieldTooltip,
                  onPressed: () => _remove(row),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const Icon(Icons.public, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      key: Key('addresses-country-$i'),
                      isExpanded: true,
                      value: row.country ?? '',
                      hint: Text(l.contactAddressCountry),
                      items: [
                        for (final c in [...knownAddressCountries, ''])
                          DropdownMenuItem(
                            value: c,
                            child: Text(_countryName(c, l)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        _setCountry(row, v.isEmpty ? null : v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _fields(context, l, i, row),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields(
    BuildContext context,
    AppLocalizations l,
    int i,
    _Row row,
  ) {
    Widget field(
      String key,
      TextEditingController c,
      String label, {
      int maxLines = 1,
      int? minLines,
      String? error,
      TextInputType? keyboard,
    }) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextField(
        key: Key('addresses-$key-$i'),
        controller: c,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType:
            keyboard ??
            (maxLines > 1
                ? TextInputType.multiline
                : TextInputType.streetAddress),
        decoration: InputDecoration(labelText: label, errorText: error),
        onChanged: (_) => _edited(row),
      ),
    );

    final country = row.country;
    if (country == null) {
      return [
        field(
          'value',
          row.text,
          l.contactFieldAddress,
          minLines: 2,
          maxLines: 5,
        ),
      ];
    }

    String? postalError() {
      if (!row.postalInvalid) return null;
      return switch (country) {
        'US' => l.contactAddressInvalidZip,
        'CA' => l.contactAddressInvalidCaPostal,
        _ => l.contactAddressInvalidCnPostal,
      };
    }

    final regionTitle = switch (country) {
      'US' => l.contactAddressState,
      'CA' => l.contactAddressProvinceTerritory,
      _ => l.contactAddressCnProvince,
    };
    final region = _regionField(i, row, regionTitle, l);

    if (country == 'CN') {
      return [
        region,
        field('city', row.city, l.contactAddressCity),
        field('district', row.district, l.contactAddressCnDistrict),
        field(
          'street1',
          row.street1,
          l.contactAddressCnDetail,
          minLines: 2,
          maxLines: 4,
        ),
        field(
          'postal',
          row.postal,
          l.contactAddressPostalCode,
          error: postalError(),
          keyboard: TextInputType.number,
        ),
      ];
    }
    return [
      field('street1', row.street1, l.contactAddressStreet),
      field('street2', row.street2, l.contactAddressUnit),
      field('city', row.city, l.contactAddressCity),
      region,
      field(
        'postal',
        row.postal,
        country == 'US' ? l.contactAddressZip : l.contactAddressPostalCode,
        error: postalError(),
        keyboard: TextInputType.text,
      ),
    ];
  }

  Widget _regionField(int i, _Row row, String title, AppLocalizations l) {
    final code = row.region;
    final name = code == null
        ? null
        : findRegion(row.country, code)?.displayName ?? code;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        key: Key('addresses-region-$i'),
        onTap: () => _pickRegion(row, title),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: title,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(name ?? l.contactAddressRegionSelect),
        ),
      ),
    );
  }
}
