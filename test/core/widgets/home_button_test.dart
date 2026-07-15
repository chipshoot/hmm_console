import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/router.dart';
import 'package:hmm_console/core/widgets/home_button.dart';

void main() {
  testWidgets('tapping Home navigates the app GoRouter to "/"',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/other',
      routes: [
        GoRoute(path: '/', builder: (c, s) => const Text('dashboard')),
        GoRoute(
          path: '/other',
          builder: (c, s) => const Scaffold(body: HomeButton()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [AppRouter.config.overrideWithValue(router)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('dashboard'), findsNothing);

    await tester.tap(find.byType(HomeButton));
    await tester.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
  });
}
