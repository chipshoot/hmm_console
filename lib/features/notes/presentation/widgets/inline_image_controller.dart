import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/util/uuid.dart';
import 'inline_insert.dart';

/// Outcome of resolving staged inline images on save.
class InlineResolveResult {
  const InlineResolveResult({required this.newRefs, required this.hadFailures});

  /// Vault refs for the picks that were persisted this save.
  final List<VaultRef> newRefs;

  /// True if any referenced pick failed/was missing and its placeholder was
  /// stripped from the body.
  final bool hadFailures;
}

/// Reusable inline-image editing capability shared by note editors (general
/// notes, service records, ...). Owns the staged pending picks + placeholder
/// insertion; on save persists the picks and rewrites the body's
/// `pending/<uuid>` placeholders to real vault paths.
///
/// It deliberately does NOT reconcile the note's attachment set — that differs
/// per editor — it only returns the new refs so the caller composes retention.
class InlineImageController {
  final Map<String, Uint8List> _pendingBytes = {};
  final Map<String, PickedImageBytes> _pendingPickByUuid = {};

  /// Staged bytes keyed by uuid — pass to `NoteMarkdownBody(pendingBytes:)`.
  Map<String, Uint8List> get pendingBytes => _pendingBytes;

  /// Stages [pick] and inserts a pending image placeholder at [body]'s caret.
  void stageAndInsert(TextEditingController body, PickedImageBytes pick) {
    final uuid = generateUuid();
    _pendingBytes[uuid] = pick.bytes;
    _pendingPickByUuid[uuid] = pick;
    insertImageAtCursor(body, uuid, pick.originalName);
  }

  /// Persists every staged pick still referenced in [body] (via [persist]),
  /// rewrites its placeholder to the real vault path, and STRIPS any
  /// placeholder whose pick failed/was missing so no `pending/` URI survives.
  /// Mutates `body.text` to the resolved string and clears staged state.
  Future<InlineResolveResult> resolveAndRewrite({
    required int noteId,
    required TextEditingController body,
    required Future<VaultRef> Function(int noteId, PickedImageBytes pick)
        persist,
  }) async {
    final uuidToPath = <String, String>{};
    final newRefs = <VaultRef>[];
    final failed = <String>[];
    for (final uuid in pendingUuidsIn(body.text)) {
      final pick = _pendingPickByUuid[uuid];
      if (pick == null) {
        failed.add(uuid);
        continue;
      }
      try {
        final vref = await persist(noteId, pick);
        uuidToPath[uuid] = vref.path;
        newRefs.add(vref);
      } catch (_) {
        failed.add(uuid);
      }
    }
    var text = rewritePendingToVault(body.text, uuidToPath);
    for (final uuid in failed) {
      text = removePendingImage(text, uuid);
    }
    body.text = text;
    _pendingBytes.clear();
    _pendingPickByUuid.clear();
    return InlineResolveResult(newRefs: newRefs, hadFailures: failed.isNotEmpty);
  }

  /// True if any staged pick still referenced in [bodyText] is sensitive.
  /// Used by the editor's save path (Task B5) to gate on the vault being
  /// unlocked BEFORE [resolveAndRewrite] ever calls [persist] — a
  /// `VaultLockedException` there would otherwise be swallowed and the
  /// placeholder silently stripped.
  bool hasSensitivePendingIn(String bodyText) {
    for (final uuid in pendingUuidsIn(bodyText)) {
      final pick = _pendingPickByUuid[uuid];
      if (pick != null && pick.sensitive) return true;
    }
    return false;
  }

  /// Vault paths referenced inline at load but no longer in [currentBody] — the
  /// caller confirms before dropping them from the note's retention set.
  static List<String> removedImagePaths(
      List<String> loadedInlinePaths, String currentBody) {
    final current = imageRefPathsIn(currentBody).toSet();
    return loadedInlinePaths.where((p) => !current.contains(p)).toList();
  }
}
