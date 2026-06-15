import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_list_row.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders title, primary, secondary, trailing', (t) async {
    await t.pumpWidget(_host(const AppListRow(
      leading: CircleAvatar(radius: 6),
      title: Text('Toyota Camry'),
      primary: Text('Insurance renewal due June 30'),
      secondary: Text('Automobile'),
      trailing: Text('9:41 AM'),
    )));
    expect(find.text('Toyota Camry'), findsOneWidget);
    expect(find.text('Insurance renewal due June 30'), findsOneWidget);
    expect(find.text('Automobile'), findsOneWidget);
    expect(find.text('9:41 AM'), findsOneWidget);
  });

  testWidgets('tap fires onTap callback', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(AppListRow(
      title: const Text('Row'),
      onTap: () => tapped = true,
    )));
    await t.tap(find.text('Row'));
    expect(tapped, isTrue);
  });

  testWidgets('omitted optional slots are absent', (t) async {
    await t.pumpWidget(_host(const AppListRow(title: Text('Only title'))));
    expect(find.text('Only title'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });
}
