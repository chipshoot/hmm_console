import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/launcher/domain/launcher_destination.dart';
import 'package:hmm_console/features/launcher/domain/vehicle_resolution.dart';

Automobile _auto(int id) =>
    Automobile(id: id, year: 2020, meterReading: 0, isActive: true);

const _gas = LauncherDestination(
    id: 'gasLog', title: 'Gas Log', icon: Icons.abc, routeName: 'gasLogList',
    needsVehicle: true, usesVehiclePathId: false);
const _svc = LauncherDestination(
    id: 'serviceRecords', title: 'Service', icon: Icons.abc, routeName: 'serviceRecords',
    needsVehicle: true, usesVehiclePathId: true);
const _notes = LauncherDestination(
    id: 'notes', title: 'Notes', icon: Icons.abc, routeName: 'notesList');

void main() {
  group('pickVehicle', () {
    test('returns the selected id when set', () {
      expect(pickVehicle(selectedId: 7, automobiles: [_auto(1), _auto(2)]), 7);
    });
    test('falls back to the only vehicle', () {
      expect(pickVehicle(selectedId: null, automobiles: [_auto(3)]), 3);
    });
    test('returns null when none selected and multiple exist', () {
      expect(pickVehicle(selectedId: null, automobiles: [_auto(1), _auto(2)]), isNull);
    });
    test('returns null when no vehicles', () {
      expect(pickVehicle(selectedId: null, automobiles: const []), isNull);
    });
  });

  group('resolveTarget', () {
    test('non-vehicle destination -> its route, no params', () {
      final t = resolveTarget(_notes, null);
      expect(t.routeName, 'notesList');
      expect(t.pathParameters, isEmpty);
      expect(t.selectVehicleId, isNull);
    });
    test('vehicle destination, unresolved -> automobile selector', () {
      final t = resolveTarget(_svc, null);
      expect(t.routeName, 'automobileSelector');
      expect(t.selectVehicleId, isNull);
    });
    test('path-id vehicle destination -> id param + select', () {
      final t = resolveTarget(_svc, 5);
      expect(t.routeName, 'serviceRecords');
      expect(t.pathParameters, {'id': '5'});
      expect(t.selectVehicleId, 5);
    });
    test('provider-scoped vehicle destination (gas log) -> no path param, select', () {
      final t = resolveTarget(_gas, 9);
      expect(t.routeName, 'gasLogList');
      expect(t.pathParameters, isEmpty);
      expect(t.selectVehicleId, 9);
    });
  });
}
