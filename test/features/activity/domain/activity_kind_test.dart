import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/activity_kind.dart';
import 'package:hmm_console/features/activity/domain/builtin_activity_kinds.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  final registry = ActivityKindRegistry(builtinActivityKinds);
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  test('nine kinds with unique ids', () {
    expect(registry.all.length, 9);
    expect(registry.all.map((k) => k.id).toSet().length, 9);
  });

  test('lookup, distance and areas', () {
    expect(registry.byId('health.walk')!.offersDistance, isTrue);
    expect(registry.byId('reading.reading')!.offersDistance, isFalse);
    expect(registry.byId('health.unknown'), isNull);
    expect(registry.areas, ['health', 'reading', 'development']);
    expect(registry.inArea('health').length, 7);
    expect(registry.byId('health.run')!.area, 'health');
  });

  test('default intensities', () {
    ActivityIntensity? d(String id) => registry.byId(id)!.defaultIntensity;
    expect(d('health.run'), ActivityIntensity.vigorous);
    for (final id in [
      'health.walk',
      'health.cycling',
      'health.swim',
      'health.gym',
      'health.yoga',
    ]) {
      expect(d(id), ActivityIntensity.moderate);
    }
    for (final id in [
      'health.other',
      'reading.reading',
      'development.coding',
    ]) {
      expect(d(id), isNull);
    }
  });

  test('labels are non-empty and localized', () {
    for (final k in registry.all) {
      expect(k.label(en), isNotEmpty);
      expect(k.label(en), isNot(k.label(zh)), reason: k.id);
    }
    expect(activityAreaLabel('health', en), 'Health');
    expect(activityAreaLabel('development', zh), '开发');
    expect(activityAreaLabel('mystery', en), 'mystery');
  });
}
