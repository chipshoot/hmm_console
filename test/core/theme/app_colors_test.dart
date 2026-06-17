import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';

void main() {
  test('light and dark differ on label + background, share accent', () {
    expect(AppColors.light.label, const Color(0xFF1C1C1E));
    expect(AppColors.dark.label, const Color(0xFFFFFFFF));
    expect(AppColors.light.groupedBackground, const Color(0xFFF2F2F7));
    expect(AppColors.dark.groupedBackground, const Color(0xFF000000));
    expect(AppColors.light.secondaryGroupedBackground, const Color(0xFFFFFFFF));
    expect(AppColors.dark.secondaryGroupedBackground, const Color(0xFF1C1C1E));
    expect(AppColors.light.accent, AppColors.dark.accent);
    expect(AppColors.light.accent, const Color(0xFF0A84FF));
  });

  test('lerp at t=0 returns this, t=1 returns other', () {
    final mid = AppColors.light.lerp(AppColors.dark, 1.0);
    expect(mid.label, AppColors.dark.label);
    final start = AppColors.light.lerp(AppColors.dark, 0.0);
    expect(start.label, AppColors.light.label);
  });

  testWidgets('context.appColors resolves the registered extension', (t) async {
    late AppColors resolved;
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Builder(builder: (c) {
        resolved = c.appColors;
        return const SizedBox();
      }),
    ));
    expect(resolved.label, AppColors.light.label);
  });
}
