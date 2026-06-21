// Picker glue: open the platform image picker, downsize + copy bytes
// into the vault, return a VaultRef the caller writes onto the note.
//
// v1 always emits VaultRef and copies bytes (never a link to the
// originating photo — see the "link vs copy" decision in
// docs/attachments-design.md "Storage policy"). Before storing, the
// bytes pass through an [ImageDownsizer] so the vault holds a
// reasonably-sized JPEG, not the full-resolution original. Phases
// 16/17 add the smart-reference shortcuts (PhAssetRef on iOS,
// CloudFileRef on macOS/Windows) on top of this entry point.

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../util/uuid.dart';
import '../../vault/vault_path.dart';
import '../../vault/vault_store.dart';
import '../attachment_ref.dart';
import 'image_downsizer.dart';

/// Source of an image pick.
enum AttachmentPickSource { gallery, camera }

/// Maximum bytes accepted client-side (mirrors server policy in
/// `docs/attachments-design.md`).
const int kMaxAttachmentBytes = 8 * 1024 * 1024;

/// MIME types the v1 client will produce. Anything else → reject.
const Set<String> _allowedContentTypes = {
  'image/jpeg',
  'image/png',
  'image/heic',
  'image/webp',
};

/// Non-image file types accepted by [persistFileToVault] (Phase 3a).
const Set<String> _allowedFileContentTypes = {
  'application/pdf',
  'audio/mp4',
};

abstract interface class IImageAttachmentPicker {
  /// Open the platform picker. Returns null if the user cancels.
  /// Throws [AttachmentPickerException] for too-large files or
  /// unsupported types.
  Future<VaultRef?> pickForNote({
    required int noteId,
    AttachmentPickSource source = AttachmentPickSource.gallery,
  });

  /// Persist already-picked bytes into the vault for [noteId]. Used by the
  /// editor to attach images held in state once the note is saved.
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
  });

  /// Persist a non-image file (e.g. PDF) into the vault for [noteId] — stores
  /// the bytes RAW (no downsizing/transcoding, unlike [persistToVault]).
  /// Used by the editor to attach files held in state once the note is saved.
  Future<VaultRef> persistFileToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    required String contentType,
  });
}

class AttachmentPickerException implements Exception {
  const AttachmentPickerException(this.message);
  final String message;

  @override
  String toString() => 'AttachmentPickerException: $message';
}

/// Default implementation backed by `package:image_picker`. Copies
/// every picked image into the vault — no smart references in v1.
class VaultImageAttachmentPicker implements IImageAttachmentPicker {
  /// [vaultStore] is the destination for the picked bytes.
  /// [picker] is injectable so tests can substitute a fake; in
  /// production we instantiate the default [ImagePicker].
  VaultImageAttachmentPicker({
    required this.vaultStore,
    ImagePicker? picker,
    ImageDownsizer downsizer = const NoopImageDownsizer(),
  })  : _picker = picker ?? ImagePicker(),
        _downsizer = downsizer;

  final IVaultStore vaultStore;
  final ImagePicker _picker;
  final ImageDownsizer _downsizer;

  @override
  Future<VaultRef?> pickForNote({
    required int noteId,
    AttachmentPickSource source = AttachmentPickSource.gallery,
  }) async {
    final XFile? picked = await _picker.pickImage(
      source: source == AttachmentPickSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final originalName = p.basename(picked.path);
    return persistToVault(
      noteId: noteId,
      bytes: bytes,
      originalName: originalName,
      contentTypeHint: picked.mimeType,
    );
  }

  /// Pure-ish helper: given raw bytes + the source file's name +
  /// optional content-type hint, copy into the vault and return a
  /// VaultRef. Exposed (rather than private) so tests and headless
  /// callers (e.g. "import from a file path") can drive the
  /// same path without going through `image_picker`.
  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
  }) async {
    if (bytes.lengthInBytes == 0) {
      throw const AttachmentPickerException('empty file');
    }
    if (bytes.lengthInBytes > kMaxAttachmentBytes) {
      throw AttachmentPickerException(
        'file is ${bytes.lengthInBytes} bytes; max is $kMaxAttachmentBytes',
      );
    }

    final inputContentType = _resolveContentType(originalName, contentTypeHint);
    if (!_allowedContentTypes.contains(inputContentType)) {
      throw AttachmentPickerException(
        'content type "$inputContentType" not allowed; expected one of '
        '$_allowedContentTypes',
      );
    }

    // Downsize-on-copy: shrink before we persist. The downsizer may
    // transcode to JPEG, so the STORED bytes, content type, and
    // byteSize all come from its result — not the original pick.
    final downsized =
        await _downsizer.downsize(bytes, contentType: inputContentType);
    final storedBytes = downsized.bytes;
    final storedContentType = downsized.contentType;

    final ext = _extFor(storedContentType);
    final path = vaultRelativePathJoin([
      'attachments',
      'note-$noteId',
      '${generateUuid()}.$ext',
    ]);
    await vaultStore.putBytes(path, storedBytes,
        contentType: storedContentType);

    return VaultRef(
      path: path,
      originalName: originalName.isEmpty ? null : originalName,
      contentType: storedContentType,
      byteSize: storedBytes.lengthInBytes,
    );
  }

  @override
  Future<VaultRef> persistFileToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    required String contentType,
  }) async {
    if (bytes.lengthInBytes == 0) {
      throw const AttachmentPickerException('empty file');
    }
    if (bytes.lengthInBytes > kMaxAttachmentBytes) {
      throw AttachmentPickerException(
        'file is ${bytes.lengthInBytes} bytes; max is $kMaxAttachmentBytes',
      );
    }
    if (!_allowedFileContentTypes.contains(contentType)) {
      throw AttachmentPickerException(
        'content type "$contentType" not allowed; expected one of '
        '$_allowedFileContentTypes',
      );
    }

    // Files are stored RAW — no downsizing/transcoding.
    final ext = _extFor(contentType);
    final path = vaultRelativePathJoin([
      'attachments',
      'note-$noteId',
      '${generateUuid()}.$ext',
    ]);
    await vaultStore.putBytes(path, bytes, contentType: contentType);

    return VaultRef(
      path: path,
      originalName: originalName.isEmpty ? null : originalName,
      contentType: contentType,
      byteSize: bytes.lengthInBytes,
    );
  }

  String _resolveContentType(String originalName, String? hint) {
    // Trust the hint if it's in the allow-list; otherwise infer from
    // the file extension. Hint can be wrong (image_picker on Android
    // has been known to claim "image/*"); the extension is the more
    // reliable fallback.
    if (hint != null && _allowedContentTypes.contains(hint)) return hint;
    final ext = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' || 'heif' => 'image/heic',
      'webp' => 'image/webp',
      _ => hint ?? '',
    };
  }

  String _extFor(String contentType) => switch (contentType) {
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/heic' => 'heic',
        'image/webp' => 'webp',
        'application/pdf' => 'pdf',
        'audio/mp4' => 'm4a',
        _ => 'bin',
      };
}
