import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/launcher/domain/launcher_matcher.dart';
import 'package:hmm_console/features/launcher/domain/launcher_registry.dart';

void main() {
  late AppLocalizations en;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final names = RouterNames.values.map((r) => r.name).toSet();

  test('every destination routeName is a real RouterNames value', () {
    for (final d in launcherDestinations(en)) {
      expect(
        names.contains(d.routeName),
        isTrue,
        reason: '${d.id} -> ${d.routeName} is not a RouterNames value',
      );
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

  test('activity destinations are found by 运动 and hidden in Cloud API', () {
    final byId = launcherDestinationsById(en);
    expect(
      match(
        '运动',
        registry: launcherDestinations(en),
        aliases: const {},
      ).map((d) => d.id),
      contains('activity'),
    );
    expect(byId['activity']?.routeName, RouterNames.activity.name);
    expect(byId['activityLog']?.routeName, RouterNames.activityCreate.name);
    expect(
      launcherDestinations(en, mode: DataMode.local).map((d) => d.id),
      containsAll(['activity', 'activityLog']),
    );
    final cloud = launcherDestinations(
      en,
      mode: DataMode.cloudApi,
    ).map((d) => d.id);
    expect(cloud, isNot(contains('activity')));
    expect(cloud, isNot(contains('activityLog')));
  });
}
