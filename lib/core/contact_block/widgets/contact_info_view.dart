import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/gaps.dart';
import '../contact_info.dart';

/// Read-only rendering of one embedded contact block.
///
/// The tap actions are reported rather than launched here, so the owning
/// screen keeps whatever launch policy it already has and this widget stays
/// testable without a platform channel.
class ContactInfoView extends StatelessWidget {
  const ContactInfoView({
    super.key,
    required this.value,
    this.onCall,
    this.onEmail,
    this.onMap,
  });

  final ContactInfo value;
  final ValueChanged<String>? onCall;
  final ValueChanged<String>? onEmail;
  final ValueChanged<String>? onMap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Framed and spaced to match ContactInfoEditor, so a block looks like the
    // same object whether it is being read or edited.
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // No heading at all when there is neither a name nor an
            // organization: the rows speak for themselves.
            if (value.displayName.isNotEmpty) ...[
              Text(value.displayName, style: theme.textTheme.titleMedium),
              GapWidgets.h4,
            ],
            // Only shown when it is not already the heading, so an unnamed
            // organization is not printed twice.
            if ((value.organization ?? '').isNotEmpty &&
                value.displayName != value.organization) ...[
              Text(value.organization!, style: theme.textTheme.bodyMedium),
              GapWidgets.h4,
            ],
            GapWidgets.h4,
            _row(context, Icons.phone, value.phone, onCall, 'contactCallRow',
                label: l.contactFieldPhone),
            _row(context, Icons.smartphone, value.mobile, onCall,
                'contactMobileRow',
                label: l.contactFieldMobile),
            // Fax is never tappable: there is nothing sensible for the OS to
            // do with it, and a dead-looking tap target is worse than none.
            _row(context, Icons.print, value.fax, null, 'contactFaxRow',
                label: l.contactFieldFax),
            _row(context, Icons.email, value.email, onEmail, 'contactEmailRow',
                label: l.contactFieldEmail),
            _addressRow(context),
            if ((value.notes ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(value.notes!, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String? text,
    ValueChanged<String>? onTap,
    String keyName, {
    String? label,
  }) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(
      key: Key(keyName),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon),
      title: Text(text),
      // Three numbers in a row are indistinguishable by icon alone once you
      // stop looking closely, so each says which one it is.
      subtitle: label == null ? null : Text(label),
      onTap: onTap == null ? null : () => onTap(text),
    );
  }

  /// The address on its own rows, so a long one reads like a printed label
  /// rather than one wrapped line.
  ///
  /// The tap still hands out `singleLine`: a maps app wants one searchable
  /// string, and that keeps the [onMap] contract unchanged for callers.
  Widget _addressRow(BuildContext context) {
    final a = value.address;
    if (a == null || a.isEmpty) return const SizedBox.shrink();
    final lines = a.displayLines;
    if (lines.isEmpty) return const SizedBox.shrink();

    return ListTile(
      key: const Key('contactMapRow'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.map),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in lines) Text(line)],
      ),
      onTap: onMap == null ? null : () => onMap!(a.singleLine),
    );
  }
}
