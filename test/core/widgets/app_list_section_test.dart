import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_list_section.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('N rows produce N-1 separators (none after the last)', (t) async {
    await t.pumpWidget(_host(const AppListSection(
      children: [
        Text('a'),
        Text('b'),
        Text('c'),
      ],
    )));
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('single row has no separators', (t) async {
    await t.pumpWidget(_host(const AppListSection(children: [Text('only')])));
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('header label renders when provided', (t) async {
    await t.pumpWidget(_host(const AppListSection(
      header: 'RECENT',
      children: [Text('row')],
    )));
    expect(find.text('RECENT'), findsOneWidget);
  });
}
