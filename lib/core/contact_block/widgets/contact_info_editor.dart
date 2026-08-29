import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/gaps.dart';
import '../../widgets/text_field.dart';
import '../contact_info.dart';

/// The reusable editor for one embedded contact block.
///
/// Drop this into any form whose record carries `contacts`. It owns no state
/// beyond its text controllers: edits are reported through [onChanged] so the
/// owning form keeps being the single source of truth for its record.
class ContactInfoEditor extends StatefulWidget {
  const ContactInfoEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.onRemove,
  });

  final ContactInfo value;
  final ValueChanged<ContactInfo> onChanged;

  /// Omitted when the owner shows exactly one block and removing it makes no
  /// sense.
  final VoidCallback? onRemove;

  @override
  State<ContactInfoEditor> createState() => _ContactInfoEditorState();
}

/// Digits plus the punctuation people actually write numbers with.
///
/// The reported bug was that a dash could not be typed. Two separate things
/// caused that and both are fixed here: this formatter (which decides what the
/// field ACCEPTS, and so also governs paste and hardware keyboards) and the
/// keyboard type below (which decides what keys iOS OFFERS).
final _phoneInput =
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() .#*]'));

/// `numberWithOptions(signed: true)` asks iOS for the numbers-and-punctuation
/// keyboard, which HAS a dash key. Plain `TextInputType.phone` is the phone
/// pad — digits and `+*#` only — which is why the dash could not be typed.
const _phoneKeyboard = TextInputType.numberWithOptions(signed: true);

class _ContactInfoEditorState extends State<ContactInfoEditor> {
  late final TextEditingController _name;
  late final TextEditingController _organization;
  late final TextEditingController _phone;
  late final TextEditingController _mobile;
  late final TextEditingController _fax;
  late final TextEditingController _email;
  late final TextEditingController _street;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _postalCode;
  late final TextEditingController _country;
  late final TextEditingController _notes;

  /// Extras are held HERE, not read from widget.value on demand. The parent
  /// updates its list in place without setState on every keystroke, so
  /// widget.value goes stale between rebuilds; emitting from it discarded text
  /// the user had just typed.
  late Map<String, dynamic> _extras;

  /// The address's own preserved keys, carried across edits for the same
  /// reason: this editor models five address fields and must not drop a sixth
  /// one written by a newer client.
  late Map<String, dynamic> _addressExtras;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _extras = v.extraFields;
    _addressExtras = v.address?.extraFields ?? const {};
    _name = TextEditingController(text: v.name);
    _organization = TextEditingController(text: v.organization ?? '');
    _phone = TextEditingController(text: v.phone ?? '');
    _mobile = TextEditingController(text: v.mobile ?? '');
    _fax = TextEditingController(text: v.fax ?? '');
    _email = TextEditingController(text: v.email ?? '');
    _street = TextEditingController(text: v.address?.street ?? '');
    _city = TextEditingController(text: v.address?.city ?? '');
    _region = TextEditingController(text: v.address?.region ?? '');
    _postalCode = TextEditingController(text: v.address?.postalCode ?? '');
    _country = TextEditingController(text: v.address?.country ?? '');
    _notes = TextEditingController(text: v.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant ContactInfoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.value;
    final a = v.address;

    // Rows are keyed by position, so removing a block hands this State to the
    // NEXT block's value without initState running again. Without this the
    // fields kept showing the removed block's text while the model underneath
    // had moved on, and the next edit merged the two into a hybrid.
    //
    // Guarded on a real difference: resyncing on every parent rebuild would
    // reset the caret mid-edit.
    final differs = v.name != _name.text ||
        (v.organization ?? '') != _organization.text ||
        (v.phone ?? '') != _phone.text ||
        (v.mobile ?? '') != _mobile.text ||
        (v.fax ?? '') != _fax.text ||
        (v.email ?? '') != _email.text ||
        (a?.street ?? '') != _street.text ||
        (a?.city ?? '') != _city.text ||
        (a?.region ?? '') != _region.text ||
        (a?.postalCode ?? '') != _postalCode.text ||
        (a?.country ?? '') != _country.text ||
        (v.notes ?? '') != _notes.text;
    if (!differs) return;

    _name.text = v.name;
    _organization.text = v.organization ?? '';
    _phone.text = v.phone ?? '';
    _mobile.text = v.mobile ?? '';
    _fax.text = v.fax ?? '';
    _email.text = v.email ?? '';
    _street.text = a?.street ?? '';
    _city.text = a?.city ?? '';
    _region.text = a?.region ?? '';
    _postalCode.text = a?.postalCode ?? '';
    _country.text = a?.country ?? '';
    _notes.text = v.notes ?? '';
    setState(() {
      _extras = v.extraFields;
      _addressExtras = a?.extraFields ?? const {};
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _organization.dispose();
    _phone.dispose();
    _mobile.dispose();
    _fax.dispose();
    _email.dispose();
    _street.dispose();
    _city.dispose();
    _region.dispose();
    _postalCode.dispose();
    _country.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Empty text means "absent", not an empty string, so a cleared field does
  /// not persist as `""` and then read back as a present-but-blank value.
  String? _orNull(String s) => s.trim().isEmpty ? null : s;

  void _emit() {
    final address = ContactAddress(
      street: _orNull(_street.text),
      city: _orNull(_city.text),
      region: _orNull(_region.text),
      postalCode: _orNull(_postalCode.text),
      country: _orNull(_country.text),
      extraFields: _addressExtras,
    );

    // Constructed directly, NOT via copyWith: copyWith reads `phone ?? this
    // .phone`, so passing null means "keep what was there" and a field the
    // user cleared could never actually be cleared. extraFields is carried
    // across by hand because this editor does not own it.
    widget.onChanged(ContactInfo(
      name: _name.text,
      organization: _orNull(_organization.text),
      phone: _orNull(_phone.text),
      mobile: _orNull(_mobile.text),
      fax: _orNull(_fax.text),
      email: _orNull(_email.text),
      // An address the user emptied becomes absent rather than an empty
      // object, matching how every scalar field here clears.
      address: address.isEmpty ? null : address,
      notes: _orNull(_notes.text),
      extraFields: _extras,
    ));
  }

  Widget _phoneField(String key, TextEditingController c, String label,
          List<String> hints) =>
      AppTextFormField(
        key: Key(key),
        fieldController: c,
        fieldValidator: (_) => null,
        label: label,
        keyboardType: _phoneKeyboard,
        inputFormatters: [_phoneInput],
        autofillHints: hints,
        onChanged: (_) => _emit(),
      );

  Widget _textField(
    String key,
    TextEditingController c,
    String label, {
    List<String>? hints,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
  }) =>
      AppTextFormField(
        key: Key(key),
        fieldController: c,
        fieldValidator: (_) => null,
        label: label,
        keyboardType: keyboard,
        autofillHints: hints,
        textCapitalization: capitalization,
        onChanged: (_) => _emit(),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Bordered so each block reads as one contact. Unboxed, several blocks of
    // outlined fields run together into a single undifferentiated stack.
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        // Grouped so the OS can offer a whole saved contact or address at
        // once rather than one field at a time.
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _textField(
                        'contactNameField', _name, l.contactFieldName,
                        hints: const [AutofillHints.name]),
                  ),
                  if (widget.onRemove != null) ...[
                    GapWidgets.w4,
                    // Nudged down to sit on the field's centre line rather
                    // than its label.
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: IconButton(
                        key: const Key('contactRemoveButton'),
                        tooltip: l.contactBlockRemove,
                        icon: const Icon(Icons.close),
                        onPressed: widget.onRemove,
                      ),
                    ),
                  ],
                ],
              ),
              GapWidgets.h16,
              _textField('contactOrganizationField', _organization,
                  l.contactFieldOrganization,
                  hints: const [AutofillHints.organizationName]),
              GapWidgets.h16,
              _phoneField('contactPhoneField', _phone, l.contactFieldPhone,
                  const [AutofillHints.telephoneNumber]),
              GapWidgets.h16,
              _phoneField('contactMobileField', _mobile, l.contactFieldMobile,
                  const [AutofillHints.telephoneNumberDevice]),
              GapWidgets.h16,
              // No autofill hint: the platform has no notion of a fax number,
              // and offering the mobile hint here would suggest the wrong one.
              _phoneField('contactFaxField', _fax, l.contactFieldFax, const []),
              GapWidgets.h16,
              _textField('contactEmailField', _email, l.contactFieldEmail,
                  hints: const [AutofillHints.email],
                  keyboard: TextInputType.emailAddress),
              GapWidgets.h24,
              Text(
                l.contactFieldAddress,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
              GapWidgets.h8,
              _textField('contactStreetField', _street, l.contactFieldStreet,
                  hints: const [AutofillHints.streetAddressLine1]),
              GapWidgets.h16,
              // Paired because a city and its province are one thought, and
              // splitting the row keeps the postal code off a line of its own
              // where it is easy to miss.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _textField(
                        'contactCityField', _city, l.contactFieldCity,
                        hints: const [AutofillHints.addressCity]),
                  ),
                  GapWidgets.w12,
                  Expanded(
                    flex: 2,
                    child: _textField(
                        'contactRegionField', _region, l.contactFieldRegion,
                        hints: const [AutofillHints.addressState]),
                  ),
                ],
              ),
              GapWidgets.h16,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _textField('contactPostalCodeField', _postalCode,
                        l.contactFieldPostalCode,
                        hints: const [AutofillHints.postalCode],
                        // Postal codes are conventionally uppercase and
                        // shift-typing one on a phone is a chore.
                        capitalization: TextCapitalization.characters),
                  ),
                  GapWidgets.w12,
                  Expanded(
                    child: _textField(
                        'contactCountryField', _country, l.contactFieldCountry,
                        hints: const [AutofillHints.countryName]),
                  ),
                ],
              ),
              GapWidgets.h24,
              _textField('contactNotesField', _notes, l.contactFieldNotes),
            ],
          ),
        ),
      ),
    );
  }
}
