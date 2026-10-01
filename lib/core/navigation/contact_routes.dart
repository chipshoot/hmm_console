import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/contacts/presentation/screens/contact_detail_screen.dart';
import '../../features/contacts/presentation/screens/contact_edit_screen.dart';
import '../../features/contacts/presentation/screens/contacts_list_screen.dart';
import 'route_names.dart';

/// The contacts route subtree, spread into the app router.
///
/// Standalone so it can be mounted in a bare [GoRouter] under test, away from
/// the auth redirect (see `cheatsheet_routes.dart`).
///
/// `new` is declared before `:id` because GoRouter matches in order; reversed,
/// `/contacts/new` would resolve as a contact whose id is literally "new".
final contactRoutes = <RouteBase>[
  GoRoute(
    path: '/contacts',
    name: RouterNames.contacts.name,
    builder: (context, state) => const ContactsListScreen(),
    routes: [
      GoRoute(
        path: 'new',
        name: RouterNames.contactCreate.name,
        builder: (context, state) => const ContactEditScreen(),
      ),
      GoRoute(
        path: ':id',
        name: RouterNames.contactDetail.name,
        // Keyed by id: go_router's declarative page key comes from the path
        // template, so /contacts/A and /contacts/B would otherwise share a
        // key under context.go and reuse the previous contact's State.
        builder: (context, state) => ContactDetailScreen(
          key: ValueKey('contact-detail-${state.pathParameters['id']}'),
          contactId: state.pathParameters['id']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            name: RouterNames.contactEdit.name,
            // ContactEditScreen pins its initial contact in State and does not
            // reset on a contactId change, so each id needs its own State.
            builder: (context, state) => ContactEditScreen(
              key: ValueKey('contact-edit-${state.pathParameters['id']}'),
              contactId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  ),
];
