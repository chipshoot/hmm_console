import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = SyncableSettingsRepository.notesSavedSearchesKey;
final _one = jsonEncode([
  {'id': 'a', 'name': 'Oil', 'order': 0, 'query': <String, Object?>{}},
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a bundle without notesSavedSearches leaves local ones untouched',
    () async {
      SharedPreferences.setMockInitialValues({_key: _one});
      final json = SyncableSettings.defaults().toJson()
        ..remove('notesSavedSearches');
      final bundle = SyncableSettings.fromJson(json);
      expect(bundle.notesSavedSearches, isNull);
      final repo = SyncableSettingsRepository();
      await repo.apply(bundle);
      expect((await repo.read()).notesSavedSearches!.single.id, 'a');
      expect((await SharedPreferences.getInstance()).getString(_key), _one);
    },
  );

  test('an explicit empty list clears them', () async {
    SharedPreferences.setMockInitialValues({_key: _one});
    final repo = SyncableSettingsRepository();
    await repo.apply(
      SyncableSettings.fromJson(
        SyncableSettings.defaults().toJson()..['notesSavedSearches'] = [],
      ),
    );
    expect((await repo.read()).notesSavedSearches, isEmpty);
  });

  test('toJson always writes notesSavedSearches', () {
    expect(SyncableSettings.defaults().toJson()['notesSavedSearches'], isEmpty);
  });

  test('saved searches round-trip through the bundle and prefs', () async {
    SharedPreferences.setMockInitialValues({_key: _one});
    final repo = SyncableSettingsRepository();
    final back = SyncableSettings.fromJson((await repo.read()).toJson());
    expect(back.notesSavedSearches!.single.name, 'Oil');
  });

  test('unreadable stored JSON reads as empty', () async {
    SharedPreferences.setMockInitialValues({_key: '{not json'});
    expect(
      (await SyncableSettingsRepository().read()).notesSavedSearches,
      isEmpty,
    );
  });
}
