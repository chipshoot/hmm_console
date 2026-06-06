import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notes/catalog_palette.dart';
import '../../../core/notes/rendering/general_note_renderer.dart';
import '../../../core/notes/rendering/generic_json_renderer.dart';
import '../../../core/notes/rendering/note_renderer.dart';
import '../../gas_log/rendering/gas_log_note_renderer.dart';

class NoteRenderRegistry {
  const NoteRenderRegistry(this._byCatalog);

  final Map<String, NoteRenderer> _byCatalog;
  static const NoteRenderer _fallback = GenericJsonRenderer();

  NoteRenderer rendererFor(String? catalogName) {
    if (catalogName == null) return _fallback;
    return _byCatalog[catalogName] ?? _fallback;
  }
}

final noteRenderRegistryProvider = Provider<NoteRenderRegistry>((ref) {
  return const NoteRenderRegistry({
    kGeneralCatalogName: GeneralNoteRenderer(),
    GasLogNoteRenderer.catalogName: GasLogNoteRenderer(),
  });
});
