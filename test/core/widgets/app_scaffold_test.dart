import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_scaffold.dart';

Widget _host(TargetPlatform platform) => MaterialApp(
  theme: ThemeData(platform: platform, extensions: const [AppColors.light]),
  home: const AppScaffold(
    title: 'Notes',
    slivers: [SliverToBoxAdapter(child: Text('body'))],
  ),
);

void main() {
  testWidgets('iOS uses the Cupertino large-title nav bar', (t) async {
    await t.pumpWidget(_host(TargetPlatform.iOS));
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('Android uses the MD3 SliverAppBar', (t) async {
    await t.pumpWidget(_host(TargetPlatform.android));
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });

  group('leading actions and pane titles', () {
    Future<void> pushInto(
      WidgetTester t,
      TargetPlatform platform,
      Widget page, {
      Size size = const Size(400, 800),
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: platform,
            extensions: const [AppColors.light],
          ),
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  c,
                ).push(MaterialPageRoute<void>(builder: (_) => page)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    const action = SizedBox(key: Key('lead'), width: 40, height: 40);

    testWidgets('iOS puts leading actions right after the back button', (
      t,
    ) async {
      await pushInto(
        t,
        TargetPlatform.iOS,
        const AppScaffold(
          title: 'Notes',
          leadingActions: [action],
          slivers: [SliverToBoxAdapter(child: Text('body'))],
        ),
      );
      final back = t.getRect(find.byKey(const Key('appScaffoldBack')));
      final lead = t.getRect(find.byKey(const Key('lead')));
      expect(lead.left, greaterThanOrEqualTo(back.right));
      expect(lead.left - back.right, lessThan(8));
    });

    testWidgets('Android puts leading actions right after the back button', (
      t,
    ) async {
      await pushInto(
        t,
        TargetPlatform.android,
        const AppScaffold(
          title: 'Notes',
          leadingActions: [action],
          slivers: [SliverToBoxAdapter(child: Text('body'))],
        ),
      );
      final back = t.getRect(find.byType(BackButton));
      final lead = t.getRect(find.byKey(const Key('lead')));
      expect(lead.left, greaterThanOrEqualTo(back.right));
      expect(lead.left - back.right, lessThan(8));
    });

    Widget pane({required bool follows}) => Row(
      children: [
        SizedBox(
          width: 360,
          child: AppScaffold(
            title: 'Notes',
            largeTitleFollowsPane: follows,
            slivers: const [SliverToBoxAdapter(child: Text('body'))],
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );

    testWidgets('a tall pane on a landscape screen gets the large title row', (
      t,
    ) async {
      await pushInto(
        t,
        TargetPlatform.iOS,
        pane(follows: true),
        size: const Size(1194, 834),
      );
      final title = find.text('Notes').first;
      expect(t.getRect(title).top, greaterThanOrEqualTo(44));
    });

    testWidgets('without the option the landscape title stays inline', (
      t,
    ) async {
      await pushInto(
        t,
        TargetPlatform.iOS,
        pane(follows: false),
        size: const Size(1194, 834),
      );
      expect(t.getRect(find.text('Notes').first).top, lessThan(44));
    });

    testWidgets('the title never wraps onto a second line', (t) async {
      await t.pumpWidget(_host(TargetPlatform.iOS));
      for (final e in find.text('Notes').evaluate()) {
        expect((e.widget as Text).maxLines, 1);
      }
    });
  });
}
