// Moves a picked video into the vault: the poster as bytes, the video by
// path so it never passes through Dart memory.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../util/uuid.dart';
import '../../vault/vault_file_store.dart';
import '../../vault/vault_path.dart';
import '../../vault/vault_store.dart';
import '../attachment_providers.dart';
import '../attachment_ref.dart';
import '../video_attachment.dart';
import 'video_picker.dart';

class VideoAttachmentStore {
  VideoAttachmentStore({required this.files, required this.vault});

  final IVaultFileStore files;
  final IVaultStore vault;

  Future<VideoAttachment> persist({
    required int noteId,
    required PickedVideo pick,
  }) async {
    final uuid = generateUuid();
    final ext = kVideoExtByContentType[pick.contentType] ?? 'mov';
    String pathFor(String e) =>
        vaultRelativePathJoin(['attachments', 'note-$noteId', '$uuid.$e']);

    VaultRef? poster;
    final bytes = pick.posterBytes;
    if (bytes != null && bytes.isNotEmpty) {
      final posterPath = pathFor('jpg');
      await vault.putBytes(posterPath, bytes, contentType: 'image/jpeg');
      poster = VaultRef(
        path: posterPath,
        contentType: 'image/jpeg',
        byteSize: bytes.length,
      );
    }
    final videoPath = pathFor(ext);
    await files.importFile(videoPath, File(pick.tempPath));
    return VideoAttachment(
      video: VaultRef(
        path: videoPath,
        originalName: pick.originalName,
        contentType: pick.contentType,
        byteSize: pick.byteSize,
      ),
      poster: poster,
      durationMs: pick.durationMs,
      width: pick.width,
      height: pick.height,
    );
  }
}

final videoAttachmentStoreProvider = FutureProvider<VideoAttachmentStore?>((
  ref,
) async {
  final files = await ref.watch(vaultFileStoreProvider.future);
  if (files == null) return null;
  final vault = await ref.watch(vaultStoreProvider.future);
  return VideoAttachmentStore(files: files, vault: vault);
});
