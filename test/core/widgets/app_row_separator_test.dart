import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_list_row.dart';
import 'package:hmm_console/core/widgets/app_row_separator.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders a hairline Divider with the given indent and separator color',
      (t) async {
    await t.pumpWidget(_host(const AppRowSeparator(indent: 52)));
    final divider = t.widget<Divider>(find.byType(Divider));
    expect(divider.height, 1);
    expect(divider.thickness, 0.5);
    expect(divider.indent, 52);
    expect(divider.color, AppColors.light.separator);
  });

  testWidgets('default indent is kRowInsetWithLeading', (t) async {
    await t.pumpWidget(_host(const AppRowSeparator()));
    final divider = t.widget<Divider>(find.byType(Divider));
    expect(divider.indent, kRowInsetWithLeading);
  });
}
