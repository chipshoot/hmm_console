import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/navigation/cheatsheet_routes.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

class _NoNotes implements IHmmNoteRepository {
  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

class _SeededCheatsheets extends CheatsheetsState {
  @override
  Future<List<CheatsheetCard>> build() async => const [
        CheatsheetCard(
          id: 'c1',
          title: 'Claim',
          walletGroup: 'Vehicle',
          tags: [],
          templateId: 'blank',
          rows: [],
        ),
      ];
}

void main() {
  Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
    final router =
        GoRouter(initialLocation: location, routes: cheatsheetRoutes);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hmmNoteRepositoryProvider.overrideWithValue(_NoNotes()),
          cheatsheetsStateProvider.overrideWith(_SeededCheatsheets.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('/cheatsheets builds the wallet', (tester) async {
    await pumpAt(tester, '/cheatsheets');
    expect(find.byType(CheatsheetWalletScreen), findsOneWidget);
  });

  testWidgets('/cheatsheets/new builds the designer in create mode',
      (tester) async {
    await pumpAt(tester, '/cheatsheets/new');

    final designer = tester.widget<CheatsheetDesignerScreen>(
      find.byType(CheatsheetDesignerScreen),
    );
    expect(designer.cardId, isNull, reason: 'create mode');
  });

  testWidgets('/cheatsheets/:id builds the detail for that card',
      (tester) async {
    await pumpAt(tester, '/cheatsheets/c1');

    final detail = tester.widget<CheatsheetDetailScreen>(
      find.byType(CheatsheetDetailScreen),
    );
    expect(detail.cardId, 'c1');
  });

  testWidgets('/cheatsheets/:id/edit builds the designer for that card',
      (tester) async {
    await pumpAt(tester, '/cheatsheets/c1/edit');

    final designer = tester.widget<CheatsheetDesignerScreen>(
      find.byType(CheatsheetDesignerScreen),
    );
    expect(designer.cardId, 'c1', reason: 'edit mode carries the id');
  });

  testWidgets('"new" is matched as the create route, not as a card id',
      (tester) async {
    // Route order matters: with ':id' declared first, /cheatsheets/new would
    // open a detail screen for a card literally called "new".
    await pumpAt(tester, '/cheatsheets/new');

    expect(find.byType(CheatsheetDesignerScreen), findsOneWidget);
    expect(find.byType(CheatsheetDetailScreen), findsNothing);
  });

  testWidgets('every route is reachable by name', (tester) async {
    final router = await pumpAt(tester, '/cheatsheets');

    router.pushNamed(RouterNames.cheatsheetCreate.name);
    await tester.pumpAndSettle();
    expect(find.byType(CheatsheetDesignerScreen), findsOneWidget);

    router.pushNamed(
      RouterNames.cheatsheetDetail.name,
      pathParameters: {'id': 'c1'},
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheatsheetDetailScreen), findsOneWidget);

    router.pushNamed(
      RouterNames.cheatsheetEdit.name,
      pathParameters: {'id': 'c1'},
    );
    await tester.pumpAndSettle();
    final designer = tester.widget<CheatsheetDesignerScreen>(
      find.byType(CheatsheetDesignerScreen),
    );
    expect(designer.cardId, 'c1');
  });
}
