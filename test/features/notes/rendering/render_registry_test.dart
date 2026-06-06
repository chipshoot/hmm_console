import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/core/notes/rendering/general_note_renderer.dart';
import 'package:hmm_console/core/notes/rendering/generic_json_renderer.dart';
import 'package:hmm_console/features/gas_log/rendering/gas_log_note_renderer.dart';
import 'package:hmm_console/features/notes/rendering/render_registry.dart';

void main() {
  test('resolves registered renderers, falls back otherwise', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reg = container.read(noteRenderRegistryProvider);

    expect(reg.rendererFor(kGeneralCatalogName), isA<GeneralNoteRenderer>());
    expect(reg.rendererFor(GasLogNoteRenderer.catalogName),
        isA<GasLogNoteRenderer>());
    expect(reg.rendererFor('Unknown.Catalog'), isA<GenericJsonRenderer>());
    expect(reg.rendererFor(null), isA<GenericJsonRenderer>());
  });
}
