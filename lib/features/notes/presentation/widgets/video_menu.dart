import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/video/video_downloads.dart';
import '../../../../core/data/attachments/video/video_platform.dart';
import '../../../../core/data/data_mode.dart';
import '../../../../core/data/attachments/attachment_ref.dart'
    show NoteAttachments;
import '../../../../core/data/attachments/video_attachment.dart';
import '../../../../core/data/vault/vault_file_store.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../states/mutate_note_state.dart';
import '../screens/note_detail_screen.dart' show noteDetailProvider;
import 'note_actions_menu.dart' show shareOriginFor;

enum _VideoAction { save, share, remove }

/// Long-press menu of a saved video: Save to Photos, Share…, Remove from note.
Future<void> showVideoMenu(
  BuildContext context,
  WidgetRef ref, {
  required int noteId,
  required VideoAttachment video,
}) async {
  final l = AppLocalizations.of(context);
  final platform = Theme.of(context).platform;
  final apple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  final origin = shareOriginFor(context, context);
  final _VideoAction? choice;
  if (apple) {
    choice = await showCupertinoModalPopup<_VideoAction>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _VideoAction.save),
            child: Text(l.notesVideoSaveToPhotos),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _VideoAction.share),
            child: Text(l.notesVideoShare),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, _VideoAction.remove),
            child: Text(l.notesVideoRemove),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.commonCancel),
        ),
      ),
    );
  } else {
    choice = await showModalBottomSheet<_VideoAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l.notesVideoSaveToPhotos),
              onTap: () => Navigator.pop(ctx, _VideoAction.save),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l.notesVideoShare),
              onTap: () => Navigator.pop(ctx, _VideoAction.share),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.notesVideoRemove),
              onTap: () => Navigator.pop(ctx, _VideoAction.remove),
            ),
          ],
        ),
      ),
    );
  }
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _VideoAction.save:
      await _save(context, ref, video);
    case _VideoAction.share:
      await _share(context, ref, video, origin);
    case _VideoAction.remove:
      await _remove(context, ref, noteId, video);
  }
}

/// The video's local file, downloading it first in cloudStorage mode when this
/// device doesn't have it. Says why and returns null when it can't.
Future<File?> _fileOrFetch(
  AppLocalizations l,
  VideoDownloads downloads,
  Future<IVaultFileStore?> storeFuture,
  bool cloud,
  String path,
  void Function(String) say,
) async {
  final local = await (await storeFuture)?.localFile(path);
  if (local != null) return local;
  if (!cloud) {
    say(l.notesVideoNotOnDevice);
    return null;
  }
  final r = await downloads.fetch(path);
  switch (r.outcome) {
    case VideoFetchOutcome.ready:
      return r.file;
    case VideoFetchOutcome.stillUploading:
      say(l.notesVideoStillUploading);
    case VideoFetchOutcome.failed:
      say(l.notesVideoDownloadFailed);
    case VideoFetchOutcome.cancelled:
      break;
  }
  return null;
}

Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  VideoAttachment video,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final platform = ref.read(videoPlatformProvider);
  final filesFuture = ref.read(vaultFileStoreProvider.future);
  final downloads = ref.read(videoDownloadsProvider.notifier);
  final cloud = ref.read(dataModeProvider) == DataMode.cloudStorage;
  void say(String t) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));
  try {
    final f = await _fileOrFetch(
      l,
      downloads,
      filesFuture,
      cloud,
      video.video.path,
      say,
    );
    if (f == null) return;
    final ok = await platform.saveToPhotos(f.path);
    say(ok ? l.notesVideoSaved : l.notesVideoPhotosDenied);
  } catch (e) {
    debugPrint('video save failed (${e.runtimeType})');
    say(l.notesVideoSaveFailed);
  }
}

Future<void> _share(
  BuildContext context,
  WidgetRef ref,
  VideoAttachment video,
  Rect origin,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final filesFuture = ref.read(vaultFileStoreProvider.future);
  final downloads = ref.read(videoDownloadsProvider.notifier);
  final cloud = ref.read(dataModeProvider) == DataMode.cloudStorage;
  void say(String t) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));
  try {
    final f = await _fileOrFetch(
      l,
      downloads,
      filesFuture,
      cloud,
      video.video.path,
      say,
    );
    if (f == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: video.video.contentType)],
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    debugPrint('video share failed (${e.runtimeType})');
    say(l.notesVideoShareFailed);
  }
}

Future<void> _remove(
  BuildContext context,
  WidgetRef ref,
  int noteId,
  VideoAttachment video,
) {
  final l = AppLocalizations.of(context);
  final mutate = ref.read(mutateNoteProvider);
  final container = ProviderScope.containerOf(context);
  ({String body, NoteAttachments attachments})? previous;
  return showUndoableAction(
    context,
    busyKey: ('removeVideo', noteId, video.video.path),
    run: () async {
      previous = await mutate.removeVideo(noteId, video);
      if (previous == null) throw StateError('Note $noteId not found');
      container.invalidate(noteDetailProvider(noteId));
    },
    undo: () async {
      final p = previous;
      if (p == null) return;
      await mutate.restoreBodyAndAttachments(noteId, p.body, p.attachments);
      container.invalidate(noteDetailProvider(noteId));
    },
    done: l.notesVideoRemoved,
    failed: l.notesVideoRemoveFailed,
    undone: l.notesVideoRestored,
    undoFailed: l.notesVideoRestoreFailed,
  );
}
