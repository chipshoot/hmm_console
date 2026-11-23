import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/dashboard/domain/home_tiles.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:hmm_console/features/settings/providers/home_hidden_tiles_provider.dart';
import 'package:hmm_console/features/settings/providers/settings_bus_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'home.hiddenTiles';

SyncableSettings _bundle(List<String>? v) =>
    SyncableSettings.defaults().copyWith(homeHiddenTiles: v);

Future<ProviderContainer> _container() async {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  c.read(homeHiddenTilesProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SyncableSettings.homeHiddenTiles', () {
    test('JSON round-trip keeps the list', () {
      final back = SyncableSettings.fromJson(
        _bundle(['glucose', 'future']).toJson(),
      );
      expect(back.homeHiddenTiles, ['glucose', 'future']);
    });

    test('an old bundle without the key decodes null and omits it', () {
      expect(SyncableSettings.fromJson({'_v': 1}).homeHiddenTiles, isNull);
      expect(
        SyncableSettings.defaults().toJson().containsKey('homeHiddenTiles'),
        isFalse,
      );
    });

    test('apply with null leaves the local value alone', () async {
      SharedPreferences.setMockInitialValues({
        _key: ['glucose'],
      });
      final repo = SyncableSettingsRepository();
      await repo.apply(_bundle(null));
      expect((await SharedPreferences.getInstance()).getStringList(_key), [
        'glucose',
      ]);
      expect((await repo.read()).homeHiddenTiles, ['glucose']);
    });

    test('apply writes the list; read gives null when never set', () async {
      final repo = SyncableSettingsRepository();
      expect((await repo.read()).homeHiddenTiles, isNull);
      await repo.apply(_bundle(['notes']));
      expect((await repo.read()).homeHiddenTiles, ['notes']);
    });
  });

  group('homeHiddenTilesProvider', () {
    test('hides and shows, persists and bumps the stamp', () async {
      final c = await _container();
      expect(c.read(homeHiddenTilesProvider), isEmpty);
      await c
          .read(homeHiddenTilesProvider.notifier)
          .setVisible('glucose', false);
      expect(c.read(homeHiddenTilesProvider), {'glucose'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_key), ['glucose']);
      expect(prefs.getString('settings.last_modified'), isNotNull);
      await c
          .read(homeHiddenTilesProvider.notifier)
          .setVisible('glucose', true);
      expect(c.read(homeHiddenTilesProvider), isEmpty);
    });

    test('loads the stored set and keeps unknown ids', () async {
      SharedPreferences.setMockInitialValues({
        _key: ['glucose', 'from-newer-build'],
      });
      final c = await _container();
      expect(c.read(homeHiddenTilesProvider), {'glucose', 'from-newer-build'});
      await c.read(homeHiddenTilesProvider.notifier).setVisible('notes', false);
      expect(c.read(homeHiddenTilesProvider), contains('from-newer-build'));
    });

    test('unknown ids do not count against the last-visible rule', () async {
      SharedPreferences.setMockInitialValues({
        _key: ['from-newer-build'],
      });
      final c = await _container();
      final n = c.read(homeHiddenTilesProvider.notifier);
      for (final t in homeTiles.skip(1)) {
        await n.setVisible(t.route, false);
      }
      await n.setVisible(homeTiles.first.route, false);
      expect(
        c.read(homeHiddenTilesProvider),
        isNot(contains(homeTiles.first.route)),
      );
    });

    test('refuses to hide the last visible tile', () async {
      final c = await _container();
      final n = c.read(homeHiddenTilesProvider.notifier);
      final ids = homeTiles.map((t) => t.route).toList();
      for (final id in ids.skip(1)) {
        await n.setVisible(id, false);
      }
      expect(c.read(homeHiddenTilesProvider).length, ids.length - 1);
      await n.setVisible(ids.first, false);
      expect(c.read(homeHiddenTilesProvider).length, ids.length - 1);
      expect(c.read(homeHiddenTilesProvider), isNot(contains(ids.first)));
    });
  });

  test('apply with [] clears a locally hidden tile', () async {
    SharedPreferences.setMockInitialValues({
      _key: ['glucose'],
    });
    await SyncableSettingsRepository().apply(_bundle([]));
    expect(
      (await SharedPreferences.getInstance()).getStringList(_key),
      isEmpty,
    );
    final c = await _container();
    expect(c.read(homeHiddenTilesProvider), isEmpty);
  });

  test('a settings-bus bump re-hydrates from prefs', () async {
    final c = await _container();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ['notes']);
    c.read(settingsBusProvider.notifier).bump();
    c.read(homeHiddenTilesProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(homeHiddenTilesProvider), {'notes'});
  });

  test('setVisible before the load finishes keeps the stored set', () async {
    SharedPreferences.setMockInitialValues({
      _key: ['glucose'],
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(homeHiddenTilesProvider.notifier).setVisible('notes', false);
    expect(c.read(homeHiddenTilesProvider), {'glucose', 'notes'});
    expect((await SharedPreferences.getInstance()).getStringList(_key), [
      'glucose',
      'notes',
    ]);
  });

  test(
    'all tiles stored hidden: the first one is effectively visible',
    () async {
      SharedPreferences.setMockInitialValues({
        _key: [for (final t in homeTiles) t.route],
      });
      final c = await _container();
      expect(c.read(homeHiddenTilesProvider).length, homeTiles.length);
      final eff = c.read(effectiveHiddenTilesProvider);
      expect(eff, isNot(contains(homeTiles.first.route)));
      expect(eff.length, homeTiles.length - 1);
    },
  );
}
