import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/core/notes/editing/edit_dispatch.dart';

void main() {
  test('canEdit is true for wired catalogs, false otherwise', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final d = container.read(editDispatchProvider);

    expect(d.canEdit(kGeneralCatalogName), isTrue);
    expect(d.canEdit('Hmm.AutomobileMan.GasLog'), isTrue);
    expect(d.canEdit('Hmm.AutomobileMan.AutomobileInfo'), isFalse);
    expect(d.canEdit(null), isFalse);
  });
}
