import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'local/database.dart';

enum DataMode {
  local,
  api;

  String get displayName => switch (this) {
        local => 'Local (Offline)',
        api => 'Cloud (API)',
      };
}

class DataModeNotifier extends Notifier<DataMode> {
  static const _key = 'data_mode';

  @override
  DataMode build() {
    _loadFromPrefs();
    return DataMode.local;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'api') {
      state = DataMode.api;
    }
  }

  Future<void> setMode(DataMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final dataModeProvider = NotifierProvider<DataModeNotifier, DataMode>(
  () => DataModeNotifier(),
);

final databasePathProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final customPath = prefs.getString('local_db_path');
  if (customPath != null && customPath.isNotEmpty) return customPath;
  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'hmm.db');
});

Future<void> updateDatabasePath(String newPath) async {
  await setDatabasePath(newPath);
}
