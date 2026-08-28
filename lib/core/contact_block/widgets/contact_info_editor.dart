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

  /// Role and extras are held HERE, not read from widget.value on demand. The
  /// parent updates its list in place without setState on every keystroke, so
  /// widget.value goes stale between rebuilds; emitting from it discarded text
  /// the user had just typed.
  late String _role;
  late Map<String, dynamic> _extras;

  @override
  void initState() {
    super.initState();
    _role = widget.value.role;
    _extras = widget.value.extraFields;
    _name = TextEditingController(text: widget.value.name);
    _organization = TextEditingController(text: widget.value.organization ?? '');
    _phone = TextEditingController(text: widget.value.phone ?? '');
    _email = TextEditingController(text: widget.value.email ?? '');
    _address = TextEditingController(text: widget.value.address ?? '');
    _notes = TextEditingController(text: widget.value.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant ContactInfoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.value;

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
        (v.email ?? '') != _email.text ||
        (v.address ?? '') != _address.text ||
        (v.notes ?? '') != _notes.text ||
        v.role != _role;
    if (!differs) return;

    _name.text = v.name;
    _organization.text = v.organization ?? '';
    _phone.text = v.phone ?? '';
    _email.text = v.email ?? '';
    _address.text = v.address ?? '';
    _notes.text = v.notes ?? '';
    setState(() {
      _role = v.role;
      _extras = v.extraFields;
    });
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
      role: _role,
      name: _name.text,
      organization: _orNull(_organization.text),
      phone: _orNull(_phone.text),
      email: _orNull(_email.text),
      address: _orNull(_address.text),
      notes: _orNull(_notes.text),
      extraFields: _extras,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    // A role the user already has but this version does not offer must stay
    // selectable, or opening the form would silently rewrite it.
    final roles =
        widget.roles.contains(_role) ? widget.roles : [_role, ...widget.roles];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('contactRoleField'),
                initialValue: _role,
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
                  if (r == null) return;
                  // Through _emit, so the live controller text travels with
                  // the role change instead of being replaced by a stale prop.
                  setState(() => _role = r);
                  _emit();
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
