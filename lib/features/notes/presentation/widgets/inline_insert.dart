import 'package:flutter/widgets.dart';

import '../../../../core/data/attachments/inline_ref_uri.dart';

/// Inserts a pending inline-image placeholder at the controller's caret,
/// surrounded by blank lines so Markdown renders it as its own block. The
/// caret is left immediately after the inserted block.
void insertImageAtCursor(
    TextEditingController controller, String uuid, String alt) {
  final block = '\n\n![$alt](${formatPendingUri(uuid)})\n\n';
  final text = controller.text;
  final sel = controller.selection;
  final at = (sel.isValid && sel.start >= 0) ? sel.start : text.length;

  final next = text.substring(0, at) + block + text.substring(at);
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: at + block.length),
  );
}

/// Inserts an inline `[label](hmm-note://<uuid>)` link at the caret, leaving the
/// caret immediately after the inserted link.
void insertNoteLinkAtCursor(
    TextEditingController controller, String uuid, String label) {
  final link = '[$label](${formatNoteUri(uuid)})';
  final text = controller.text;
  final sel = controller.selection;
  final at = (sel.isValid && sel.start >= 0) ? sel.start : text.length;
  final next = text.substring(0, at) + link + text.substring(at);
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: at + link.length),
  );
}
