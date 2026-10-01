import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/contact.dart';
import '../contact_labels.dart';

/// One row of the address book: the name, with the relationship under it.
class ContactTile extends StatelessWidget {
  const ContactTile({super.key, required this.contact, required this.onTap});

  final Contact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final custom = contact.relationship.customLabel;
    final label =
        contact.relationship.category == RelationshipCategory.other &&
            custom != null &&
            custom.isNotEmpty
        ? custom
        : relationshipLabel(contact.relationship.category, l);
    return ListTile(
      leading: Icon(
        contact.contactType == ContactType.organization
            ? Icons.business_outlined
            : Icons.person_outline,
      ),
      title: Text(contact.displayName),
      subtitle: Text(label),
      trailing: contact.isSelf
          ? Chip(
              key: const Key('contact-self-badge'),
              label: Text(l.relationshipSelf),
              visualDensity: VisualDensity.compact,
            )
          : null,
      onTap: onTap,
    );
  }
}
