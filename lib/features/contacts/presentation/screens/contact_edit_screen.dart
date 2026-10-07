import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/contact_name.dart';
import '../../domain/entities/contact.dart';
import '../../domain/pinyin_transcriber.dart';
import '../../states/contact_edit_state.dart';
import '../../states/device_region_provider.dart';
import '../../states/pinyin_transcriber_provider.dart';
import '../contact_labels.dart';
import '../widgets/address_editor.dart';
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
  late final TextEditingController _phoneticFamily;
  late final TextEditingController _phoneticGiven;
  final _addresses = GlobalKey<AddressEditorState>();

  /// "More name options": open for Chinese names or any option set; opens by
  /// itself when Chinese is typed, until the user toggles it.
  bool _nameOptionsOpen = false;
  bool _nameOptionsToggled = false;

  /// Automatic pinyin shown as grey hint text in empty phonetic fields.
  String _hintFamily = '';
  String _hintGiven = '';
  Timer? _hintDebounce;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _first = TextEditingController(text: c.firstName ?? '');
    _last = TextEditingController(text: c.lastName ?? '');
    _org = TextEditingController(text: c.organizationName ?? '');
    _custom = TextEditingController(text: c.relationship.customLabel ?? '');
    _notes = TextEditingController(text: c.notes ?? '');
    _phoneticFamily = TextEditingController(text: c.phoneticFamily ?? '');
    _phoneticGiven = TextEditingController(text: c.phoneticGiven ?? '');
    _nameOptionsOpen =
        ContactName.hasChinese(c.firstName) ||
        ContactName.hasChinese(c.lastName) ||
        c.nameOrder != ContactNameOrder.auto ||
        (c.phoneticFamily ?? '').isNotEmpty ||
        (c.phoneticGiven ?? '').isNotEmpty;
    _recomputeHints();
  }

  @override
  void dispose() {
    _hintDebounce?.cancel();
    _first.dispose();
    _last.dispose();
    _org.dispose();
    _custom.dispose();
    _notes.dispose();
    _phoneticFamily.dispose();
    _phoneticGiven.dispose();
    super.dispose();
  }

  PinyinTranscriber? _transcriber() {
    try {
      return ref.read(pinyinTranscriberProvider);
    } catch (e) {
      debugPrint('ContactEdit: pinyin unavailable (${e.runtimeType})');
      return null;
    }
  }

  /// Hints come from the same transcriber the list sorts with. A failure
  /// leaves the hint empty; type only in the log.
  void _recomputeHints() {
    final t = _transcriber();
    String hint(String part, {required bool family}) {
      if (t == null || !ContactName.hasChinese(part)) return '';
      try {
        return (family ? t.family(part) : t.given(part)).join(' ');
      } catch (e) {
        debugPrint('ContactEdit: pinyin hint failed (${e.runtimeType})');
        return '';
      }
    }

    _hintFamily = hint(_last.text, family: true);
    _hintGiven = hint(_first.text, family: false);
  }

  void _onNameChanged() {
    if (!_nameOptionsToggled &&
        !_nameOptionsOpen &&
        (ContactName.hasChinese(_first.text) ||
            ContactName.hasChinese(_last.text))) {
      setState(() => _nameOptionsOpen = true);
    }
    _hintDebounce?.cancel();
    _hintDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(_recomputeHints);
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    // Captured before the await: nothing below touches context or ref after it.
    final notifier = ref.read(
      contactEditStateProvider(widget.initial).notifier,
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Checked before any await, so the reveal and snackbar use live state.
    if (notifier.phoneticInvalid) {
      setState(() => _nameOptionsOpen = true);
      messenger.showSnackBar(
        SnackBar(content: Text(l.contactPhoneticFixToSave)),
      );
      return;
    }
    if (notifier.addressesInvalid) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.contactAddressFixPostal)),
      );
      _addresses.currentState?.revealInvalidPostal();
      return;
    }
    try {
      final saved = await notifier.save();
      if (saved && navigator.mounted) navigator.pop();
    } catch (e) {
      // Type only: SqliteException's text appends the bound parameters,
      // i.e. the whole contact JSON.
      debugPrint('ContactEdit: save failed (${e.runtimeType})');
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
    final theme = Theme.of(context);
    final chinese =
        ContactName.hasChinese(c.firstName) ||
        ContactName.hasChinese(c.lastName);
    // Keyed slots: the two fields swap places as Chinese is typed, and the
    // keys move the elements (focus, cursor) with them.
    final givenSlot = KeyedSubtree(
      key: const ValueKey('contact-given-slot'),
      child: _pad(
        TextField(
          key: const Key('contact-first-name'),
          controller: _first,
          decoration: InputDecoration(
            labelText: l.contactFirstName,
            errorText: nameError,
          ),
          onChanged: (v) {
            notifier.setFirstName(v);
            _onNameChanged();
          },
        ),
      ),
    );
    final familySlot = KeyedSubtree(
      key: const ValueKey('contact-family-slot'),
      child: _pad(
        TextField(
          key: const Key('contact-last-name'),
          controller: _last,
          decoration: InputDecoration(labelText: l.contactLastName),
          onChanged: (v) {
            notifier.setLastName(v);
            _onNameChanged();
          },
        ),
      ),
    );

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
        // Not a ListView: a lazy list disposes sections scrolled past its
        // cache extent, and the field editors would then rebuild from the
        // initial contact, reverting (and later overwriting) typed edits.
        // The form is bounded, so building it all at once is cheap.
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                // Same stored data either way; Chinese names read 姓 then 名.
                ...(chinese
                    ? [familySlot, givenSlot]
                    : [givenSlot, familySlot]),
                if (c.displayName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: Text(
                      l.contactShownAs(c.displayName),
                      key: const Key('contact-name-preview'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ListTile(
                  key: const Key('contact-name-options'),
                  leading: const Icon(Icons.translate),
                  title: Text(l.contactNameOptions),
                  trailing: Icon(
                    _nameOptionsOpen ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => setState(() {
                    _nameOptionsToggled = true;
                    _nameOptionsOpen = !_nameOptionsOpen;
                  }),
                ),
                if (_nameOptionsOpen) ...[
                  _pad(
                    Text(
                      l.contactNameOrder,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: _NameOrderToggle(
                      isIos: isIos,
                      value: c.nameOrder,
                      onChanged: notifier.setNameOrder,
                    ),
                  ),
                  _pad(
                    TextField(
                      key: const Key('contact-phonetic-family'),
                      controller: _phoneticFamily,
                      decoration: InputDecoration(
                        labelText: l.contactPhoneticFamily,
                        hintText: _hintFamily.isEmpty ? null : _hintFamily,
                        floatingLabelBehavior: _hintFamily.isEmpty
                            ? null
                            : FloatingLabelBehavior.always,
                        errorText:
                            ContactName.isValidPhonetic(c.phoneticFamily ?? '')
                            ? null
                            : l.contactPhoneticInvalid,
                      ),
                      onChanged: notifier.setPhoneticFamily,
                    ),
                  ),
                  _pad(
                    TextField(
                      key: const Key('contact-phonetic-given'),
                      controller: _phoneticGiven,
                      decoration: InputDecoration(
                        labelText: l.contactPhoneticGiven,
                        hintText: _hintGiven.isEmpty ? null : _hintGiven,
                        floatingLabelBehavior: _hintGiven.isEmpty
                            ? null
                            : FloatingLabelBehavior.always,
                        errorText:
                            ContactName.isValidPhonetic(c.phoneticGiven ?? '')
                            ? null
                            : l.contactPhoneticInvalid,
                      ),
                      onChanged: notifier.setPhoneticGiven,
                    ),
                  ),
                ],
              ],
              LabeledFieldEditor(
                keyPrefix: 'phones',
                title: l.contactPhones,
                valueLabel: l.contactFieldPhone,
                addLabel: l.contactAddPhone,
                labels: phoneFieldLabels,
                // iOS's phone pad has no `+`; the signed number pad does.
                keyboardType: isIos
                    ? const TextInputType.numberWithOptions(signed: true)
                    : TextInputType.phone,
                countryCode: true,
                defaultRegion: ref.watch(deviceRegionProvider),
                initial: [
                  for (final p in widget.initial.phones)
                    LabeledFieldEntry(
                      label: p.label,
                      value: p.number,
                      extraFields: p.extraFields,
                      rawKnownValues: p.rawKnownValues,
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
                      rawKnownValues: e.rawKnownValues,
                    ),
                ],
                onChanged: notifier.setEmails,
              ),
              AddressEditor(
                key: _addresses,
                defaultRegion: ref.watch(deviceRegionProvider),
                initial: widget.initial.addresses,
                onChanged: notifier.setAddresses,
              ),
              _pad(
                DropdownButtonFormField<RelationshipCategory>(
                  key: const Key('contact-relationship'),
                  // Driven from state: DropdownButtonFormField re-syncs when
                  // initialValue changes, so "This is me" (which files the
                  // contact under `self`) shows here at once.
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
                onChanged: (v) {
                  notifier.setIsSelf(v);
                  // setIsSelf(true) nulls the custom label; the field must not
                  // bring the stale text back if Other is picked again.
                  if (v) _custom.clear();
                },
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

/// Auto / Given name first / Family name first: Cupertino sliding control on
/// iOS, Material segmented button elsewhere (same pattern as [_TypeToggle]).
class _NameOrderToggle extends StatelessWidget {
  const _NameOrderToggle({
    required this.isIos,
    required this.value,
    required this.onChanged,
  });

  final bool isIos;
  final ContactNameOrder value;
  final ValueChanged<ContactNameOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isIos) {
      return CupertinoSlidingSegmentedControl<ContactNameOrder>(
        key: const Key('contact-name-order'),
        groupValue: value,
        children: {
          for (final o in ContactNameOrder.values)
            o: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(nameOrderLabel(o, l), textAlign: TextAlign.center),
            ),
        },
        onValueChanged: (o) {
          if (o != null) onChanged(o);
        },
      );
    }
    return SegmentedButton<ContactNameOrder>(
      key: const Key('contact-name-order'),
      showSelectedIcon: false,
      segments: [
        for (final o in ContactNameOrder.values)
          ButtonSegment(value: o, label: Text(nameOrderLabel(o, l))),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
