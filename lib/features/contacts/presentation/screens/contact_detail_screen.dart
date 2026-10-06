import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/repository_providers.dart';
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../cheatsheet/data/cheatsheet_launcher.dart';
import '../../../cheatsheet/domain/entities/cheatsheet_source.dart';
import '../../domain/address_format.dart';
import '../../domain/entities/contact.dart';
import '../../states/contacts_state.dart';
import '../contact_labels.dart';

/// Opens the edit screen for a contact. Overridable so tests can assert the
/// navigation.
final contactEditProvider = Provider<void Function(BuildContext, String)>(
  (ref) => (context, id) => context.pushNamed(
    RouterNames.contactEdit.name,
    pathParameters: {'id': id},
  ),
);

/// Resolves by id through the repository, not the active-only list, so a
/// deactivated contact still renders. Watching the list state re-reads after
/// a save.
final contactByIdProvider =
    FutureProvider.autoDispose.family<Contact?, String>((ref, id) async {
  await ref.watch(contactsStateProvider.future);
  return ref.watch(contactRepositoryModeProvider).getContact(id);
});

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    // Captured before any await: the snackbar outlives this screen.
    final state = ref.read(contactsStateProvider.notifier);
    final navigator = Navigator.of(context);
    var removed = false;
    await showUndoableAction(
      context,
      busyKey: ('contact-remove', contactId),
      run: () async {
        await state.deactivate(contactId);
        removed = true;
      },
      undo: () => state.restore(contactId),
      done: l.contactDeactivated,
      failed: l.contactDeactivateFailed,
      undone: l.contactDeactivateUndone,
      undoFailed: l.contactDeactivateUndoFailed,
    );
    if (removed && navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(contactByIdProvider(contactId));
    final contact = async.value;

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(
          actions: const [HelpButton(helpId: HelpId.contactDetail)],
        ),
        body: Center(
          child: async.isLoading
              ? const CircularProgressIndicator()
              : async.hasError
                  ? Text(l.contactsLoadFailed)
                  : Text(l.contactNotFound,
                      key: const Key('contact-not-found')),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          HmmIconButton(
            icon: Icons.edit_outlined,
            tooltip: l.contactEditTooltip,
            onPressed: () => ref.read(contactEditProvider)(context, contactId),
          ),
          HmmIconButton(
            icon: Icons.delete_outline,
            tooltip: l.contactRemoveTooltip,
            onPressed: () => _remove(context, ref),
          ),
          const HelpButton(helpId: HelpId.contactDetail),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(contact.contactType == ContactType.organization
                ? Icons.business
                : Icons.person_outline),
            title: Text(contact.displayName,
                style: theme.textTheme.titleLarge),
            subtitle: Text(
              contact.relationship.category == RelationshipCategory.other &&
                      (contact.relationship.customLabel ?? '').isNotEmpty
                  ? contact.relationship.customLabel!
                  : relationshipLabel(contact.relationship.category, l),
            ),
          ),
          if (contact.phones.isNotEmpty) ...[
            _Header(l.contactPhones),
            for (final p in contact.phones)
              _FieldRow(
                label: fieldLabelText(p.label, l),
                value: p.number,
                icon: Icons.call,
                action: ValueAction.call,
              ),
          ],
          if (contact.emails.isNotEmpty) ...[
            _Header(l.contactEmails),
            for (final e in contact.emails)
              _FieldRow(
                label: fieldLabelText(e.label, l),
                value: e.address,
                icon: Icons.email_outlined,
                action: ValueAction.none,
              ),
          ],
          if (contact.addresses.isNotEmpty) ...[
            _Header(l.contactAddresses),
            for (final a in contact.addresses)
              _FieldRow(
                label: fieldLabelText(a.label, l),
                value: a.value,
                // Structured: the country's lines. Free-form: as stored.
                display: formatMultiline(a),
                icon: Icons.map_outlined,
                action: ValueAction.map,
              ),
          ],
          if ((contact.notes ?? '').isNotEmpty) ...[
            _Header(l.contactNotes),
            ListTile(title: Text(contact.notes!)),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _FieldRow extends ConsumerWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.action,
    this.display,
  });

  final String label;

  /// What a tap launches with.
  final String value;

  /// What is shown, when it differs from [value].
  final String? display;
  final IconData icon;
  final ValueAction action;

  Future<void> _launch(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(launchActionProvider)(action, value);
    } catch (e) {
      // Everything, Errors included: the user tapped a value and must hear
      // that it did not open. Logged by type only - never the value or uri.
      debugPrint(
          'ContactDetail: launching ${action.name} failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.cheatsheetOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        leading: Icon(icon),
        title: Text(display ?? value),
        subtitle: Text(label),
        onTap: action == ValueAction.none ? null : () => _launch(context, ref),
      );
}
