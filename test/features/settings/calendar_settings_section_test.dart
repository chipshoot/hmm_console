import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/calendar/notifications/local_reminder_scheduler.dart';
import 'package:hmm_console/features/calendar/states/open_system_settings.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:hmm_console/features/calendar/states/show_lunar_provider.dart';
import 'package:hmm_console/features/settings/presentation/widgets/calendar_settings_section.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calendar/support/fake_notification_gateway.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  DataMode mode = DataMode.local,
  Future<bool> Function()? open,
  FakeNotificationGateway? gateway,
}) async {
  final c = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _Mode(mode)),
      openSystemSettingsProvider.overrideWithValue(open),
      reminderSchedulerProvider.overrideWithValue(
        LocalReminderScheduler(gateway ?? FakeNotificationGateway()),
      ),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CalendarSettingsSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

final _remindSwitch = find.descendant(
  of: find.widgetWithText(ListTile, 'Remind on this device'),
  matching: find.byType(Switch),
);
final _lunarSwitch = find.descendant(
  of: find.widgetWithText(ListTile, 'Show lunar calendar'),
  matching: find.byType(Switch),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the switch toggles and persists calendar.remindOnDevice', (
    tester,
  ) async {
    final c = await _mount(tester);
    final before = c.read(remindOnDeviceProvider);
    await tester.tap(_remindSwitch);
    await tester.pumpAndSettle();
    expect(c.read(remindOnDeviceProvider), !before);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('calendar.remindOnDevice'), !before);
  });

  testWidgets('turning the switch on asks for permission once if never asked '
      '(R-18)', (tester) async {
    final gw = _CountingGateway(granted: false);
    final c = await _mount(tester, gateway: gw);
    expect(c.read(remindOnDeviceProvider), isFalse);
    await tester.tap(_remindSwitch);
    await tester.pumpAndSettle();
    expect(gw.requests, 1);
    expect(await calendarPermissionAsked(), isTrue);
    expect(c.read(calendarPermissionDeniedProvider), isTrue);

    // Off and on again: already asked, no second prompt.
    await tester.tap(_remindSwitch);
    await tester.pumpAndSettle();
    await tester.tap(_remindSwitch);
    await tester.pumpAndSettle();
    expect(c.read(remindOnDeviceProvider), isTrue);
    expect(gw.requests, 1);
  });

  testWidgets('Open Settings row appears only when denied', (tester) async {
    var opened = 0;
    final c = await _mount(
      tester,
      open: () async {
        opened++;
        return true;
      },
    );
    expect(find.text('Open Settings'), findsNothing);
    c.read(calendarPermissionDeniedProvider.notifier).set(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    expect(opened, 1);
  });

  testWidgets('hidden in Cloud API mode', (tester) async {
    await _mount(tester, mode: DataMode.cloudApi);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Show lunar calendar'), findsNothing);
  });

  testWidgets('the lunar row toggles showLunarProvider', (tester) async {
    final c = await _mount(tester);
    expect(find.text('Show lunar calendar'), findsOneWidget);
    expect(c.read(showLunarProvider), isFalse);
    await tester.tap(_lunarSwitch);
    await tester.pumpAndSettle();
    expect(c.read(showLunarProvider), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('calendar.show_lunar'), isTrue);
  });
}

class _CountingGateway extends FakeNotificationGateway {
  _CountingGateway({super.granted});
  int requests = 0;
  @override
  Future<bool> requestPermission() async {
    requests++;
    return granted;
  }
}
