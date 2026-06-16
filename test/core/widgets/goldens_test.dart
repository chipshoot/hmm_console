import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/theme/theme.dart';
import 'package:hmm_console/core/widgets/app_list_row.dart';
import 'package:hmm_console/core/widgets/app_list_section.dart';

Widget _sampleSection() => AppListSection(
      children: const [
        AppListRow(
          leading: CircleAvatar(radius: 6, backgroundColor: Color(0xFFFF9F0A)),
          title: Text('Toyota Camry'),
          primary: Text('Insurance renewal due June 30'),
          secondary: Text('Automobile · Intact #4471'),
          trailing: Text('9:41 AM'),
        ),
        AppListRow(
          leading: CircleAvatar(radius: 6, backgroundColor: Color(0xFF34C759)),
          title: Text('Costco gas'),
          primary: Text(r'$1.42 / L · 48.2 L'),
          secondary: Text('Gas Log · 84,210 km'),
          trailing: Text('Yesterday'),
        ),
      ],
    );

Future<void> _pump(WidgetTester t, ThemeData theme) async {
  await t.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(
      backgroundColor: theme.extension<AppColors>()!.groupedBackground,
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 390, child: _sampleSection()),
      ),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('AppListSection light golden', (t) async {
    await _pump(t, AppTheme.lightThemeData);
    await expectLater(
      find.byType(AppListSection),
      matchesGoldenFile('goldens/app_list_section_light.png'),
    );
  });

  testWidgets('AppListSection dark golden', (t) async {
    await _pump(t, AppTheme.darkThemeData);
    await expectLater(
      find.byType(AppListSection),
      matchesGoldenFile('goldens/app_list_section_dark.png'),
    );
  });
}
