import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/data_mode.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../contacts/presentation/widgets/contact_photo.dart';
import '../../../contacts/states/contacts_state.dart';

/// Settings -> Profile: the "Me" contact, or a prompt to create it. Hidden in
/// cloudApi mode, where contacts are unavailable.
class ProfileRow extends ConsumerWidget {
  const ProfileRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dataModeProvider) == DataMode.cloudApi) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final contacts = ref.watch(contactsStateProvider);
    // While loading or on error, show nothing rather than a wrong prompt to
    // create a second card.
    if (!contacts.hasValue) return const SizedBox.shrink();
    final self = ref.watch(selfContactProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('settings-profile'),
          contentPadding: EdgeInsets.zero,
          leading: self == null
              ? const CircleAvatar(child: Icon(Icons.person_add_outlined))
              : ContactPhoto(contact: self, size: 40),
          title: Text(
            self == null ? l.settingsProfileCreate : self.displayName,
          ),
          subtitle: self == null ? null : Text(l.settingsProfile),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(
            self == null ? '/contacts/new?self=1' : '/contacts/${self.id}',
          ),
        ),
        const Divider(),
      ],
    );
  }
}
