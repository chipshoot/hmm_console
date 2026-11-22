import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/presentation/widgets/platform_date_time_pickers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('iOS date picker keeps the initial time of day', (t) async {
    DateTime? result;
    final initial = DateTime(2026, 11, 21, 18, 40);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showPlatformDatePicker(context, initial),
            child: const Text('pick'),
          ),
        ),
      ),
    );
    await t.tap(find.text('pick'));
    await t.pumpAndSettle();
    // In date mode the Cupertino wheel emits midnight of the picked day.
    t
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2026, 11, 19));
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(result, DateTime(2026, 11, 19, 18, 40));
  });
}
