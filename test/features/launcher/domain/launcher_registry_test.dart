import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/launcher/domain/launcher_registry.dart';

void main() {
  final names = RouterNames.values.map((r) => r.name).toSet();

  test('every destination routeName is a real RouterNames value', () {
    for (final d in launcherDestinations) {
      expect(names.contains(d.routeName), isTrue,
          reason: '${d.id} -> ${d.routeName} is not a RouterNames value');
    }
  });

  test('ids are unique', () {
    final ids = launcherDestinations.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('usesVehiclePathId implies needsVehicle', () {
    for (final d in launcherDestinations) {
      if (d.usesVehiclePathId) expect(d.needsVehicle, isTrue, reason: d.id);
    }
  });

  test('lookup map resolves a known id and returns null for unknown', () {
    expect(launcherDestinationsById['gasLog']?.title, 'Gas Log');
    expect(launcherDestinationsById['nope'], isNull);
  });
}
