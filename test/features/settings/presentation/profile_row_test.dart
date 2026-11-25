import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/auth/owner_id.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/navigation/contact_routes.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contacts_state.dart';
import 'package:hmm_console/features/settings/presentation/widgets/profile_row.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../contacts/data/contact_repository_fakes.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

const _me = Contact(
  id: 'me1',
  contactType: ContactType.person,
  firstName: 'Ada',
  lastName: 'Lovelace',
  isSelf: true,
);

Future<ProviderContainer> _pump(
  WidgetTester t,
  InMemoryContactRepository repo, {
  DataMode mode = DataMode.local,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      contactRepositoryModeProvider.overrideWithValue(repo),
      dataModeProvider.overrideWith(() => _Mode(mode)),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: ProfileRow()),
      ),
      ...contactRoutes,
    ],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await t.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('with a Me contact shows its name and opens it', (t) async {
    final repo = InMemoryContactRepository()..seed(_me);
    await _pump(t, repo);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    await t.tap(find.byKey(const Key('settings-profile')));
    await t.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.byType(ProfileRow), findsNothing);
  });

  testWidgets('without one shows Create my card and opens the editor with '
      'This is me on', (t) async {
    await _pump(t, InMemoryContactRepository());
    expect(find.text('Create my card'), findsOneWidget);
    await t.tap(find.byKey(const Key('settings-profile')));
    await t.pumpAndSettle();
    final sw = t.widget<SwitchListTile>(
      find.byKey(const Key('contact-is-self')),
    );
    expect(sw.value, isTrue);
  });

  testWidgets('hidden in cloudApi', (t) async {
    final repo = InMemoryContactRepository()..seed(_me);
    await _pump(t, repo, mode: DataMode.cloudApi);
    expect(find.byKey(const Key('settings-profile')), findsNothing);
  });

  testWidgets('renaming the Me contact does not change the owner id', (
    t,
  ) async {
    final repo = InMemoryContactRepository()..seed(_me);
    final container = await _pump(t, repo);
    final store = await container.read(ownerIdStoreProvider.future);
    await store.setOwnerIdOnce('owner-1');
    await container
        .read(contactsStateProvider.notifier)
        .save(_me.copyWith(firstName: 'Grace'));
    expect(store.ownerId, 'owner-1');
    await t.pumpAndSettle();
    expect(find.text('Grace Lovelace'), findsOneWidget);
  });
}
