import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/contact.dart';
import '../../states/contact_edit_state.dart';
import '../contact_labels.dart';
import '../widgets/labeled_field_editor.dart';
import 'contact_detail_screen.dart' show contactByIdProvider;

/// Create ([contactId] null) or edit one contact. After a successful save it
/// pops: to the list when creating, to the detail screen when editing.
class ContactEditScreen extends ConsumerStatefulWidget {
  const ContactEditScreen({super.key, this.contactId});

  final String? contactId;

  @override
  ConsumerState<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends ConsumerState<ContactEditScreen> {
  /// The contact as first loaded. Pinned so the edit session (its provider
  /// key, in-flight guard and controllers) stays stable even if the stored
  /// contact changes mid-edit or right after a save, before the pop.
  Contact? _pinned;

  @override
  Widget build(BuildContext context) {
    final id = widget.contactId;
    if (id == null) {
      return const _ContactForm(
        initial: Contact(id: '', contactType: ContactType.person),
        isCreate: true,
      );
    }
    final l = AppLocalizations.of(context);
    final async = ref.watch(contactByIdProvider(id));
    final contact = _pinned ??= async.value;
    if (contact != null) return _ContactForm(initial: contact, isCreate: false);
    return Scaffold(
      appBar: AppBar(actions: const [HelpButton(helpId: HelpId.contactEdit)]),
      body: Center(
        child: async.isLoading
            ? const CircularProgressIndicator()
            : async.hasError
            ? Text(l.contactsLoadFailed)
            : Text(l.contactNotFound, key: const Key('contact-not-found')),
      ),
    );
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm({required this.initial, required this.isCreate});

  final Contact initial;
  final bool isCreate;

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _org;
  late final TextEditingController _custom;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _first = TextEditingController(text: c.firstName ?? '');
    _last = TextEditingController(text: c.lastName ?? '');
    _org = TextEditingController(text: c.organizationName ?? '');
    _custom = TextEditingController(text: c.relationship.customLabel ?? '');
    _notes = TextEditingController(text: c.notes ?? '');
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _org.dispose();
    _custom.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    // Captured before the await: nothing below touches context or ref after it.
    final notifier = ref.read(
      contactEditStateProvider(widget.initial).notifier,
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await notifier.save();
      if (saved && navigator.mounted) navigator.pop();
    } catch (e) {
      debugPrint('ContactEdit: save failed ($e)');
      messenger.showSnackBar(SnackBar(content: Text(l.contactSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = contactEditStateProvider(widget.initial);
    final data = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final c = data.contact;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final nameError = data.nameError ? l.contactNameRequired : null;
    final isOrg = c.contactType == ContactType.organization;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreate ? l.contactAdd : l.contactEdit),
        actions: [
          HmmIconButton(
            key: const Key('contact-save'),
            icon: Icons.check,
            tooltip: l.commonSave,
            onPressed: _save,
          ),
          const HelpButton(helpId: HelpId.contactEdit),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _TypeToggle(
                isIos: isIos,
                value: c.contactType,
                onChanged: notifier.setType,
              ),
            ),
            if (isOrg)
              _pad(
                TextField(
                  key: const Key('contact-org-name'),
                  controller: _org,
                  decoration: InputDecoration(
                    labelText: l.contactOrganizationName,
                    errorText: nameError,
                  ),
                  onChanged: notifier.setOrganizationName,
                ),
              )
            else ...[
              _pad(
                TextField(
                  key: const Key('contact-first-name'),
                  controller: _first,
                  decoration: InputDecoration(
                    labelText: l.contactFirstName,
                    errorText: nameError,
                  ),
                  onChanged: notifier.setFirstName,
                ),
              ),
              _pad(
                TextField(
                  key: const Key('contact-last-name'),
                  controller: _last,
                  decoration: InputDecoration(labelText: l.contactLastName),
                  onChanged: notifier.setLastName,
                ),
              ),
            ],
            LabeledFieldEditor(
              keyPrefix: 'phones',
              title: l.contactPhones,
              valueLabel: l.contactFieldPhone,
              addLabel: l.contactAddPhone,
              labels: phoneFieldLabels,
              keyboardType: TextInputType.phone,
              initial: [
                for (final p in widget.initial.phones)
                  LabeledFieldEntry(
                    label: p.label,
                    value: p.number,
                    extraFields: p.extraFields,
                  ),
              ],
              onChanged: notifier.setPhones,
            ),
            LabeledFieldEditor(
              keyPrefix: 'emails',
              title: l.contactEmails,
              valueLabel: l.contactFieldEmail,
              addLabel: l.contactAddEmail,
              labels: emailFieldLabels,
              keyboardType: TextInputType.emailAddress,
              initial: [
                for (final e in widget.initial.emails)
                  LabeledFieldEntry(
                    label: e.label,
                    value: e.address,
                    extraFields: e.extraFields,
                  ),
              ],
              onChanged: notifier.setEmails,
            ),
            LabeledFieldEditor(
              keyPrefix: 'addresses',
              title: l.contactAddresses,
              valueLabel: l.contactFieldAddress,
              addLabel: l.contactAddAddress,
              labels: addressFieldLabels,
              keyboardType: TextInputType.streetAddress,
              initial: [
                for (final a in widget.initial.addresses)
                  LabeledFieldEntry(
                    label: a.label,
                    value: a.value,
                    extraFields: a.extraFields,
                  ),
              ],
              onChanged: notifier.setAddresses,
            ),
            _pad(
              DropdownButtonFormField<RelationshipCategory>(
                key: const Key('contact-relationship'),
                initialValue: c.relationship.category,
                decoration: InputDecoration(labelText: l.contactRelationship),
                items: [
                  for (final r in RelationshipCategory.values)
                    DropdownMenuItem(
                      value: r,
                      child: Text(relationshipLabel(r, l)),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  notifier.setRelationship(v);
                  if (v != RelationshipCategory.other) _custom.clear();
                },
              ),
            ),
            if (c.relationship.category == RelationshipCategory.other)
              _pad(
                TextField(
                  key: const Key('contact-custom-label'),
                  controller: _custom,
                  decoration: InputDecoration(
                    labelText: l.contactCustomRelationship,
                  ),
                  onChanged: notifier.setCustomLabel,
                ),
              ),
            SwitchListTile.adaptive(
              key: const Key('contact-is-self'),
              title: Text(l.contactIsSelf),
              subtitle: Text(l.contactIsSelfHint),
              value: c.isSelf,
              onChanged: notifier.setIsSelf,
            ),
            _pad(
              TextField(
                key: const Key('contact-notes'),
                controller: _notes,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: l.contactNotes),
                onChanged: notifier.setNotes,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: child,
  );
}

/// Person / organization toggle: Cupertino sliding control on iOS, Material
/// segmented button elsewhere.
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.isIos,
    required this.value,
    required this.onChanged,
  });

  final bool isIos;
  final ContactType value;
  final ValueChanged<ContactType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isIos) {
      return CupertinoSlidingSegmentedControl<ContactType>(
        key: const Key('contact-type'),
        groupValue: value,
        children: {
          for (final t in ContactType.values)
            t: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(contactTypeLabel(t, l)),
            ),
        },
        onValueChanged: (t) {
          if (t != null) onChanged(t);
        },
      );
    }
    return SegmentedButton<ContactType>(
      key: const Key('contact-type'),
      segments: [
        for (final t in ContactType.values)
          ButtonSegment(value: t, label: Text(contactTypeLabel(t, l))),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
