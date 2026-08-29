import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/auto_scheduled_service.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/scheduled_services_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/service_records_screen.dart';
import 'package:hmm_console/features/automobile_records/states/scheduled_services_state.dart';
import 'package:hmm_console/features/automobile_records/states/service_records_state.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_station.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_management_screen.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/gas_station_management_screen.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/features/gas_log/states/gas_stations_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _StubAutos extends AutomobilesState {
  @override
  Future<List<Automobile>> build() async => const [];
}

class _StubRecords extends ServiceRecordsState {
  @override
  Future<List<ServiceRecord>> build() async => const [];
}

class _StubSchedules extends ScheduledServicesState {
  @override
  Future<List<AutoScheduledService>> build() async => const [];
}

class _StubStations extends GasStationsState {
  @override
  Future<List<GasStation>> build() async => const [];
}

void main() {
  final overrides = [
    automobilesStateProvider.overrideWith(_StubAutos.new),
    serviceRecordsStateProvider.overrideWith(_StubRecords.new),
    scheduledServicesStateProvider.overrideWith(_StubSchedules.new),
    gasStationsStateProvider.overrideWith(_StubStations.new),
  ];

  Future<void> pump(
      WidgetTester tester, Widget screen, TargetPlatform platform) async {
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ));
    await tester.pump();
  }

  // Every list screen that can create a record. The project's platform rules
  // say a primary action goes in the navigation bar on iOS and on a FAB on
  // Android — so each screen must show exactly one of them, never both.
  final screens = <String, Widget>{
    'addRecordAction': const ServiceRecordsScreen(automobileId: 7),
    'addScheduleAction': const ScheduledServicesScreen(automobileId: 7),
    'addVehicleAction': const AutomobileManagementScreen(),
    'addStationAction': const GasStationManagementScreen(),
  };

  screens.forEach((key, screen) {
    testWidgets('$key sits in the app bar on iOS, with no FAB', (tester) async {
      await pump(tester, screen, TargetPlatform.iOS);

      expect(find.byKey(Key(key)), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('$key is absent on Android, where the FAB stays',
        (tester) async {
      await pump(tester, screen, TargetPlatform.android);

      expect(find.byKey(Key(key)), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
