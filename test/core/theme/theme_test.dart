import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/theme/theme.dart';

void main() {
  test('light theme registers AppColors.light and a blue scheme', () {
    final t = AppTheme.lightThemeData;
    expect(t.extension<AppColors>(), isNotNull);
    expect(t.extension<AppColors>()!.label, AppColors.light.label);
    expect(t.colorScheme.brightness, Brightness.light);
  });

  test('dark theme registers AppColors.dark (not the old green seed)', () {
    final t = AppTheme.darkThemeData;
    expect(t.extension<AppColors>()!.label, AppColors.dark.label);
    expect(t.colorScheme.brightness, Brightness.dark);
  });

  test('text theme carries the row title size', () {
    final t = AppTheme.lightThemeData;
    expect(t.textTheme.titleMedium?.fontSize, 16);
    expect(t.textTheme.titleMedium?.fontWeight, FontWeight.w600);
  });
}
