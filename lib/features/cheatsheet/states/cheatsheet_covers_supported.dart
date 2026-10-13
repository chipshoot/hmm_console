import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_mode.dart';

/// A cover needs the card note's local id and attachments column, which
/// `/v1/cheatsheets` does not expose, so cloudApi offers no cover. Read by the
/// designer's Look section and by `CheatsheetEditor.resetLook`. Overridden in
/// tests.
final cheatsheetCoversSupportedProvider = Provider<bool>(
  (ref) => ref.watch(dataModeProvider) != DataMode.cloudApi,
);
