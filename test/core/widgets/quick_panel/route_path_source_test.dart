import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/widgets/quick_panel/current_route_path.dart';

/// Regression tests for the "panel shows only Sync everywhere" bug.
///
/// The panel picks its actions from the current route path. The original
/// implementation read `routeInformationProvider.value.uri.path`, which
/// reports the LOCATION — and go_router does not move the location on an
/// imperative `push()`. This app pushes everywhere, so the panel saw "/"
/// on every screen.
///
/// The push() cases below are the ones that mattered; they fail against
/// the old implementation.
void main() {
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(path: '/notes', builder: (_, _) => const Text('notes')),
          GoRoute(path: '/gas-logs', builder: (_, _) => const Text('gas')),
          GoRoute(
            path: '/automobiles',
            builder: (_, _) => const Text('autos'),
            routes: [
              GoRoute(
                path: 'manage',
                builder: (_, _) => const Text('manage'),
                routes: [
                  GoRoute(
                    path: ':id/services',
                    builder: (_, _) => const Text('services'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  Future<GoRouter> pump(WidgetTester tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  // The next three pass against the OLD, buggy implementation too — go()
  // and pop() move the location, so both readings agree. Kept as smoke
  // tests; they are NOT regression cover for the push() bug. The tests
  // that actually bite are the push() ones below.
  testWidgets('reports / at home', (tester) async {
    final router = await pump(tester);
    expect(currentRoutePath(router), '/');
  });

  // These DO fail against the old implementation — verified.
  testWidgets('sees a pushed route (the actual bug)', (tester) async {
    final router = await pump(tester);
    router.push('/notes');
    await tester.pumpAndSettle();
    expect(currentRoutePath(router), '/notes');
  });

  testWidgets('sees a pushed gas-logs route', (tester) async {
    final router = await pump(tester);
    router.push('/gas-logs');
    await tester.pumpAndSettle();
    expect(currentRoutePath(router), '/gas-logs');
  });

  testWidgets('sees a route reached by go()', (tester) async {
    final router = await pump(tester);
    router.go('/gas-logs');
    await tester.pumpAndSettle();
    expect(currentRoutePath(router), '/gas-logs');
  });

  testWidgets('a pushed path keeps its concrete parameters', (tester) async {
    final router = await pump(tester);
    router.push('/automobiles/manage/7/services');
    await tester.pumpAndSettle();
    // The id must survive — the panel builds "<path>/new" from it.
    expect(currentRoutePath(router), '/automobiles/manage/7/services');
  });

  testWidgets('reports the TOP of the stack, not the bottom', (tester) async {
    final router = await pump(tester);
    router.push('/notes');
    await tester.pumpAndSettle();
    router.push('/gas-logs');
    await tester.pumpAndSettle();
    expect(currentRoutePath(router), '/gas-logs');
  });

  testWidgets('follows a pop back down the stack', (tester) async {
    final router = await pump(tester);
    router.push('/notes');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(currentRoutePath(router), '/');
  });
}
