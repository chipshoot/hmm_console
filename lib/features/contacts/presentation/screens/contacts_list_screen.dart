import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/i_contact_repository.dart';
import '../../domain/contact_sort.dart';
import '../../domain/entities/contact.dart';
import '../../states/contact_list_entries.dart';
import '../widgets/contact_tile.dart';

enum _Group { family, providers, other }

_Group _groupOf(RelationshipCategory c) => switch (c) {
  RelationshipCategory.self ||
  RelationshipCategory.spouse ||
  RelationshipCategory.parent ||
  RelationshipCategory.child ||
  RelationshipCategory.family => _Group.family,
  RelationshipCategory.doctor ||
  RelationshipCategory.pharmacy ||
  RelationshipCategory.insurer => _Group.providers,
  RelationshipCategory.friend || RelationshipCategory.other => _Group.other,
};

/// The address book: searchable, grouped Family / Providers / Other.
class ContactsListScreen extends ConsumerStatefulWidget {
  const ContactsListScreen({super.key});

  @override
  ConsumerState<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends ConsumerState<ContactsListScreen> {
  String _query = '';

  void _add() => context.pushNamed(RouterNames.contactCreate.name);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(contactListEntriesProvider);
    final isApple = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.contactsTitle),
        actions: [
          // FAB is the Android primary action; iOS gets a top-bar add instead.
          if (isApple)
            HmmIconButton(
              icon: Icons.add,
              tooltip: l.contactAddTooltip,
              onPressed: _add,
            ),
          const HelpButton(helpId: HelpId.contacts),
        ],
      ),
      floatingActionButton: isApple
          ? null
          : FloatingActionButton(
              tooltip: l.contactAddTooltip,
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.contactsSearchHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              // Raw: matchesSearch normalizes (case, accents, whitespace).
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) {
                if (!isContactsCloudApiUnavailable(e)) {
                  // Type only: the error text can quote stored contact data.
                  debugPrint('Contacts failed to load (${e.runtimeType})');
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      isContactsCloudApiUnavailable(e)
                          ? l.contactsCloudApiUnavailable
                          : l.contactsLoadFailed,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
              data: (all) => _body(l, all),
            ),
          ),
        ],
      ),
    );
  }

  /// [all] arrives sorted ("Me" first, then the sort key), so filtering and
  /// grouping below keep that order.
  Widget _body(AppLocalizations l, List<ContactListEntry> all) {
    final shown = [
      for (final e in all)
        if (_query.trim().isEmpty || matchesSearch(e.contact, e.terms, _query))
          e.contact,
    ];
    if (shown.isEmpty) {
      return Center(child: Text(l.contactsEmpty));
    }
    final headers = {
      _Group.family: l.contactGroupFamily,
      _Group.providers: l.contactGroupProviders,
      _Group.other: l.contactGroupOther,
    };
    final theme = Theme.of(context);
    return ListView(
      children: [
        for (final g in _Group.values)
          ...() {
            final members = shown.where(
              (c) => _groupOf(c.relationship.category) == g,
            );
            if (members.isEmpty) return <Widget>[];
            return <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  headers[g]!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final c in members)
                ContactTile(
                  contact: c,
                  onTap: () => context.pushNamed(
                    RouterNames.contactDetail.name,
                    pathParameters: {'id': c.id},
                  ),
                ),
            ];
          }(),
      ],
    );
  }
}
