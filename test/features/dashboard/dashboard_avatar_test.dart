import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contacts_state.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _User extends CurrentUserNotifier {
  _User(this._u);
  final CurrentUserDataModel? _u;
  @override
  CurrentUserDataModel? build() => _u;
}

class _IntroSeen extends IntroCardSeenNotifier {
  @override
  bool build() => true;
}

class _EmptyCheatsheets extends CheatsheetsState {
  @override
  Future<List<CheatsheetCard>> build() async => const [];
}

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

class _FakeSync extends SyncController {
  _FakeSync() : super(syncAction: () async => throw UnimplementedError());
  @override
  SyncStatus get status => const SyncStatus();
}

class _Contacts extends ContactsState {
  _Contacts(this._list);
  final List<Contact> _list;
  @override
  Future<List<Contact>> build() async => _list;
}

const _tester = CurrentUserDataModel(
  uid: 'u1',
  email: 'tester@example.com',
  displayName: 'Tester',
  photoUrl: null,
);

const _me = Contact(
  id: 'c-me',
  contactType: ContactType.person,
  firstName: 'Ada',
  lastName: 'Lovelace',
  isSelf: true,
);

const _other = Contact(
  id: 'c-2',
  contactType: ContactType.person,
  firstName: 'Bob',
  lastName: 'Stone',
);

Future<void> _pump(
  WidgetTester tester, {
  required DataMode mode,
  CurrentUserDataModel? user,
  List<Contact> contacts = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(() => _User(user)),
        introCardSeenProvider.overrideWith(_IntroSeen.new),
        cheatsheetsStateProvider.overrideWith(_EmptyCheatsheets.new),
        dataModeProvider.overrideWith(() => _StubMode(mode)),
        syncControllerProvider.overrideWithValue(_FakeSync()),
        contactsStateProvider.overrideWith(() => _Contacts(contacts)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _inAvatar(Finder f) =>
    find.descendant(of: find.byKey(const Key('dashboardAvatar')), matching: f);

void main() {
  testWidgets('no login, Me card: shows the card initials, not "?"', (
    tester,
  ) async {
    await _pump(tester, mode: DataMode.local, contacts: const [_other, _me]);
    expect(_inAvatar(find.text('AL')), findsOneWidget);
    expect(_inAvatar(find.text('?')), findsNothing);
  });

  testWidgets('no login, no Me card: shows a person icon, not "?"', (
    tester,
  ) async {
    await _pump(tester, mode: DataMode.cloudStorage, contacts: const [_other]);
    expect(_inAvatar(find.byIcon(Icons.person_outline)), findsOneWidget);
    expect(_inAvatar(find.text('?')), findsNothing);
  });

  testWidgets('signed in with a Me card: the card wins', (tester) async {
    await _pump(
      tester,
      mode: DataMode.local,
      user: _tester,
      contacts: const [_me],
    );
    expect(_inAvatar(find.text('AL')), findsOneWidget);
    expect(_inAvatar(find.text('T')), findsNothing);
  });

  testWidgets('signed in without a Me card: the login initial', (
    tester,
  ) async {
    await _pump(tester, mode: DataMode.local, user: _tester);
    expect(_inAvatar(find.text('T')), findsOneWidget);
  });

  testWidgets('cloudApi (no contacts): the login initial', (tester) async {
    await _pump(
      tester,
      mode: DataMode.cloudApi,
      user: _tester,
      contacts: const [_me],
    );
    expect(_inAvatar(find.text('T')), findsOneWidget);
    expect(_inAvatar(find.text('AL')), findsNothing);
  });
}
