import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';

enum CoverAction { camera, library, scan, remove }

/// Where the cover comes from: the existing camera / photo-library pickers and
/// the document scanner (only when [canScan]), plus Remove when [hasCover].
/// A Cupertino action sheet on iOS, a bottom sheet elsewhere.
Future<CoverAction?> showCoverActionSheet(
  BuildContext context, {
  required bool hasCover,
  required bool canScan,
}) {
  final l = AppLocalizations.of(context);
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<CoverAction>(
      context: context,
      builder: (ctx) {
        CupertinoActionSheetAction action(
          CoverAction a,
          String label, {
          bool destructive = false,
        }) => CupertinoActionSheetAction(
          key: Key('cover-${a.name}'),
          isDestructiveAction: destructive,
          onPressed: () => Navigator.of(ctx).pop(a),
          child: Text(label),
        );
        return CupertinoActionSheet(
          title: Text(l.cheatsheetLookCover),
          actions: [
            action(CoverAction.camera, l.cheatsheetCoverCamera),
            action(CoverAction.library, l.cheatsheetCoverLibrary),
            if (canScan) action(CoverAction.scan, l.cheatsheetCoverScan),
            if (hasCover)
              action(
                CoverAction.remove,
                l.cheatsheetCoverRemove,
                destructive: true,
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.commonCancel),
          ),
        );
      },
    );
  }
  return showModalBottomSheet<CoverAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      Widget tile(CoverAction a, IconData icon, String label) => ListTile(
        key: Key('cover-${a.name}'),
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.of(ctx).pop(a),
      );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(
              CoverAction.camera,
              Icons.photo_camera_outlined,
              l.cheatsheetCoverCamera,
            ),
            tile(
              CoverAction.library,
              Icons.photo_library_outlined,
              l.cheatsheetCoverLibrary,
            ),
            if (canScan)
              tile(
                CoverAction.scan,
                Icons.document_scanner_outlined,
                l.cheatsheetCoverScan,
              ),
            if (hasCover)
              tile(
                CoverAction.remove,
                Icons.delete_outline,
                l.cheatsheetCoverRemove,
              ),
          ],
        ),
      );
    },
  );
}

/// Seam so designer widget tests never open a real sheet.
final cheatsheetCoverActionProvider =
    Provider<
      Future<CoverAction?> Function(
        BuildContext, {
        required bool hasCover,
        required bool canScan,
      })
    >((ref) => showCoverActionSheet);
