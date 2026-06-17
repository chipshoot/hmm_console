import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_scaffold.dart';

Widget _host(TargetPlatform platform) => MaterialApp(
      theme: ThemeData(platform: platform, extensions: const [AppColors.light]),
      home: const AppScaffold(
        title: 'Notes',
        slivers: [
          SliverToBoxAdapter(child: Text('body')),
        ],
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
}
