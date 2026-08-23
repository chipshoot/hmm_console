import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/launcher/domain/launcher_registry.dart';

void main() {
  late AppLocalizations en;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final names = RouterNames.values.map((r) => r.name).toSet();

  test('every destination routeName is a real RouterNames value', () {
    for (final d in launcherDestinations(en)) {
      expect(names.contains(d.routeName), isTrue,
          reason: '${d.id} -> ${d.routeName} is not a RouterNames value');
    }
  });

  test('ids are unique', () {
    final ids = launcherDestinations(en).map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('usesVehiclePathId implies needsVehicle', () {
    for (final d in launcherDestinations(en)) {
      if (d.usesVehiclePathId) expect(d.needsVehicle, isTrue, reason: d.id);
    }
  });

  test('lookup map resolves a known id and returns null for unknown', () {
    expect(launcherDestinationsById(en)['gasLog']?.title, 'Gas Log');
    expect(launcherDestinationsById(en)['nope'], isNull);
  });
}
