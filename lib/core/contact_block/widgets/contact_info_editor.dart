import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/text_field.dart';
import '../contact_info.dart';
import '../contact_info_labels.dart';

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
    this.roles = ContactRoles.known,
  });

  final ContactInfo value;
  final ValueChanged<ContactInfo> onChanged;

  /// Omitted when the owner shows exactly one block and removing it makes no
  /// sense.
  final VoidCallback? onRemove;

  final List<String> roles;

  @override
  State<ContactInfoEditor> createState() => _ContactInfoEditorState();
}

class _ContactInfoEditorState extends State<ContactInfoEditor> {
  late final TextEditingController _name;
  late final TextEditingController _organization;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.value.name);
    _organization = TextEditingController(text: widget.value.organization ?? '');
    _phone = TextEditingController(text: widget.value.phone ?? '');
    _email = TextEditingController(text: widget.value.email ?? '');
    _address = TextEditingController(text: widget.value.address ?? '');
    _notes = TextEditingController(text: widget.value.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _organization.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Empty text means "absent", not an empty string, so a cleared field does
  /// not persist as `""` and then read back as a present-but-blank value.
  String? _orNull(String s) => s.trim().isEmpty ? null : s;

  void _emit() {
    // Constructed directly, NOT via copyWith: copyWith reads `phone ?? this
    // .phone`, so passing null means "keep what was there" and a field the
    // user cleared could never actually be cleared. Role and extraFields are
    // carried across by hand because this editor does not own them.
    widget.onChanged(ContactInfo(
      role: widget.value.role,
      name: _name.text,
      organization: _orNull(_organization.text),
      phone: _orNull(_phone.text),
      email: _orNull(_email.text),
      address: _orNull(_address.text),
      notes: _orNull(_notes.text),
      extraFields: widget.value.extraFields,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    // A role the user already has but this version does not offer must stay
    // selectable, or opening the form would silently rewrite it.
    final roles = widget.roles.contains(widget.value.role)
        ? widget.roles
        : [widget.value.role, ...widget.roles];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('contactRoleField'),
                initialValue: widget.value.role,
                decoration: InputDecoration(labelText: l.contactFieldRole),
                items: [
                  for (final r in roles)
                    DropdownMenuItem(
                      value: r,
                      // The stored literal is the value; the label is only what
                      // the user reads.
                      child: Text(contactRoleLabel(r, l)),
                    ),
                ],
                onChanged: (r) {
                  if (r != null) widget.onChanged(widget.value.copyWith(role: r));
                },
              ),
            ),
            if (widget.onRemove != null)
              IconButton(
                key: const Key('contactRemoveButton'),
                tooltip: l.contactBlockRemove,
                icon: const Icon(Icons.close),
                onPressed: widget.onRemove,
              ),
          ],
        ),
        AppTextFormField(
          key: const Key('contactNameField'),
          fieldController: _name,
          fieldValidator: (_) => null,
          label: l.contactFieldName,
          onChanged: (_) => _emit(),
        ),
        AppTextFormField(
          key: const Key('contactOrganizationField'),
          fieldController: _organization,
          fieldValidator: (_) => null,
          label: l.contactFieldOrganization,
          onChanged: (_) => _emit(),
        ),
        AppTextFormField(
          key: const Key('contactPhoneField'),
          fieldController: _phone,
          fieldValidator: (_) => null,
          label: l.contactFieldPhone,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _emit(),
        ),
        AppTextFormField(
          key: const Key('contactEmailField'),
          fieldController: _email,
          fieldValidator: (_) => null,
          label: l.contactFieldEmail,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _emit(),
        ),
        AppTextFormField(
          key: const Key('contactAddressField'),
          fieldController: _address,
          fieldValidator: (_) => null,
          label: l.contactFieldAddress,
          onChanged: (_) => _emit(),
        ),
        AppTextFormField(
          key: const Key('contactNotesField'),
          fieldController: _notes,
          fieldValidator: (_) => null,
          label: l.contactFieldNotes,
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}
