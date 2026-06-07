import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/features/notes/data/general_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates General once and returns it on subsequent calls', () async {
    SharedPreferences.setMockInitialValues({}); // -> DataMode.local
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [hmmDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final first = await container.read(generalCatalogProvider.future);
    expect(first.name, kGeneralCatalogName);
    expect(first.formatType, 3);

    container.invalidate(generalCatalogProvider);
    final second = await container.read(generalCatalogProvider.future);
    expect(second.id, first.id); // not duplicated
  });
}
