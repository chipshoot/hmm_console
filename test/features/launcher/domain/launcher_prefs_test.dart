import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_prefs.dart';

void main() {
  test('round-trips through json', () {
    const p = LauncherPrefs(favorites: ['gasLog', 'notes'], aliases: {'cs': 'serviceRecords'});
    final back = LauncherPrefs.fromJson(p.toJson());
    expect(back.favorites, ['gasLog', 'notes']);
    expect(back.aliases, {'cs': 'serviceRecords'});
  });

  test('json string round-trip', () {
    const p = LauncherPrefs(favorites: ['x'], aliases: {'a': 'b'});
    expect(LauncherPrefs.fromJsonString(p.toJsonString()).aliases, {'a': 'b'});
  });

  test('absent / malformed fields default to empty', () {
    expect(LauncherPrefs.fromJson(const {}).favorites, isEmpty);
    expect(LauncherPrefs.fromJson(const {}).aliases, isEmpty);
    // wrong types are dropped, not thrown
    final p = LauncherPrefs.fromJson({'favorites': [1, 'ok'], 'aliases': {'k': 2}});
    expect(p.favorites, ['ok']);
    expect(p.aliases, isEmpty);
  });

  test('copyWith replaces fields', () {
    const p = LauncherPrefs(favorites: ['a'], aliases: {});
    expect(p.copyWith(favorites: ['b']).favorites, ['b']);
    expect(p.copyWith(aliases: {'x': 'y'}).aliases, {'x': 'y'});
  });
}
