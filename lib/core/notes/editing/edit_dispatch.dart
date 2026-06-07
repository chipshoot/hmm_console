import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/notes/data/models/hmm_note.dart';
import '../catalog_palette.dart';

typedef EditAction = void Function(BuildContext context, HmmNote note);

class EditDispatch {
  const EditDispatch(this._byCatalog);

  final Map<String, EditAction> _byCatalog;

  bool canEdit(String? catalogName) =>
      catalogName != null && _byCatalog.containsKey(catalogName);

  /// No-op if the catalog has no registered editor.
  void edit(BuildContext context, String? catalogName, HmmNote note) {
    final action = catalogName == null ? null : _byCatalog[catalogName];
    action?.call(context, note);
  }
}

final editDispatchProvider = Provider<EditDispatch>((ref) {
  return EditDispatch({
    kGeneralCatalogName: (context, note) =>
        context.push('/notes/${note.id}/edit'),
    'Hmm.AutomobileMan.GasLog': (context, note) =>
        context.push('/gas-logs/${note.id}/edit'),
  });
});
