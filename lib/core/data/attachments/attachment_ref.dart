// Tagged-union reference to one attachment on a note.
//
// See docs/attachments-design.md in the Hmm repo for the model, and
// src/Hmm.Core/Schemas/NoteAttachments.schema.json for the canonical
// JSON Schema. Keep this file's shape and the schema in sync.

import 'package:collection/collection.dart';

/// Storage providers for [CloudFileRef].
enum CloudProvider {
  oneDrive('oneDrive'),
  iCloudDrive('iCloudDrive');

  const CloudProvider(this.wireName);

  /// Value emitted in JSON.
  final String wireName;

  /// Inverse of [wireName]; throws [FormatException] on unknown input.
  static CloudProvider fromWire(String s) => switch (s) {
    'oneDrive' => CloudProvider.oneDrive,
    'iCloudDrive' => CloudProvider.iCloudDrive,
    _ => throw FormatException('Unknown cloud provider: $s'),
  };
}

/// Base of the tagged union. Use pattern matching to handle each
/// kind:
///
/// ```dart
/// switch (ref) {
///   VaultRef() => ...,
///   PhAssetRef() => ...,
///   CloudFileRef() => ...,
/// }
/// ```
sealed class AttachmentRef {
  const AttachmentRef();

  /// Wire-level discriminator ("vault" / "phasset" / "cloudFile").
  String get kind;
}

/// A file copied into the app's vault folder (per tier). Always
/// resolvable on the device that holds the vault. The only kind that
/// survives Free → Paid migration; the only kind the .NET server
/// ever sees.
final class VaultRef extends AttachmentRef {
  const VaultRef({
    required this.path,
    this.originalName,
    required this.contentType,
    required this.byteSize,
    this.sensitive = false,
  });

  /// Vault relative path; must validate against
  /// [vaultRelativePathValidate] from `lib/core/data/vault/vault_path.dart`.
  final String path;

  final String? originalName;
  final String contentType;

  /// Always present on vault refs (mandated by the schema).
  final int byteSize;

  /// Encrypted-at-rest, view-gated, AI-excluded when true. Default false;
  /// absent in JSON means false (back-compat).
  final bool sensitive;

  @override
  String get kind => 'vault';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultRef &&
          other.path == path &&
          other.originalName == originalName &&
          other.contentType == contentType &&
          other.byteSize == byteSize &&
          other.sensitive == sensitive;

  @override
  int get hashCode =>
      Object.hash(path, originalName, contentType, byteSize, sensitive);

  @override
  String toString() =>
      'VaultRef(path: $path, contentType: $contentType, '
      'byteSize: $byteSize, sensitive: $sensitive)';
}

/// A pointer into iOS Photos by PHAsset localIdentifier. iOS-only.
/// Bytes are read via PhotoKit; the cross-device path is iCloud
/// Photos.
final class PhAssetRef extends AttachmentRef {
  const PhAssetRef({
    required this.id,
    this.originalName,
    required this.contentType,
    this.byteSize,
  });

  final String id;
  final String? originalName;
  final String contentType;

  /// Nullable — PhotoKit doesn't always expose the size cheaply.
  final int? byteSize;

  @override
  String get kind => 'phasset';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhAssetRef &&
          other.id == id &&
          other.originalName == originalName &&
          other.contentType == contentType &&
          other.byteSize == byteSize;

  @override
  int get hashCode => Object.hash(id, originalName, contentType, byteSize);

  @override
  String toString() =>
      'PhAssetRef(id: $id, contentType: $contentType, byteSize: $byteSize)';
}

/// A pointer into a file the user already keeps inside a known
/// cloud-synced folder (OneDrive, iCloud Drive). Bytes are read via
/// the OS file path on platforms where that root is mounted.
final class CloudFileRef extends AttachmentRef {
  const CloudFileRef({
    required this.provider,
    required this.path,
    this.originalName,
    required this.contentType,
    this.byteSize,
  });

  final CloudProvider provider;

  /// Path relative to the provider's local mount root.
  final String path;

  final String? originalName;
  final String contentType;
  final int? byteSize;

  @override
  String get kind => 'cloudFile';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudFileRef &&
          other.provider == provider &&
          other.path == path &&
          other.originalName == originalName &&
          other.contentType == contentType &&
          other.byteSize == byteSize;

  @override
  int get hashCode =>
      Object.hash(provider, path, originalName, contentType, byteSize);

  @override
  String toString() =>
      'CloudFileRef(provider: ${provider.wireName}, '
      'path: $path, contentType: $contentType, byteSize: $byteSize)';
}

/// Per-note attachment payload — the value of the `Notes.attachments`
/// JSON column. Two slots, disjoint by construction.
///
/// Forward compatibility: entries this build cannot parse (a newer build's
/// kinds / content types) and unknown top-level keys are carried in
/// [preservedImages], [preservedFiles] and [extra] so a re-save keeps them.
final class NoteAttachments {
  /// Construct a payload. Throws [ArgumentError] if [primaryImage]
  /// appears in [images] (slots must be disjoint).
  NoteAttachments({
    this.primaryImage,
    List<AttachmentRef> images = const [],
    List<AttachmentRef> files = const [],
    List<Map<String, dynamic>> preservedImages = const [],
    List<Map<String, dynamic>> preservedFiles = const [],
    Map<String, dynamic> extra = const {},
  }) : images = List.unmodifiable(images),
       files = List.unmodifiable(files),
       preservedImages = List.unmodifiable(preservedImages),
       preservedFiles = List.unmodifiable(preservedFiles),
       extra = Map.unmodifiable(extra) {
    final p = primaryImage;
    if (p != null) {
      for (final img in images) {
        if (img == p) {
          throw ArgumentError(
            'NoteAttachments: primaryImage may not also appear in images',
          );
        }
      }
    }
  }

  /// Empty payload — equivalent to a NULL column value.
  static final NoteAttachments empty = NoteAttachments();

  final AttachmentRef? primaryImage;
  final List<AttachmentRef> images;

  /// Non-image attachments (PDF now, audio later). Rendered by content type.
  final List<AttachmentRef> files;

  /// Raw `images` entries this build does not understand, kept verbatim.
  final List<Map<String, dynamic>> preservedImages;

  /// Raw `files` entries this build does not understand, kept verbatim.
  final List<Map<String, dynamic>> preservedFiles;

  /// Unknown top-level keys, plus the raw `primaryImage` when unsupported.
  final Map<String, dynamic> extra;

  bool get isEmpty =>
      primaryImage == null &&
      images.isEmpty &&
      files.isEmpty &&
      preservedImages.isEmpty &&
      preservedFiles.isEmpty &&
      extra.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Copy with replaced slots; preserved entries and [extra] carry over.
  NoteAttachments copyWith({
    AttachmentRef? primaryImage,
    bool clearPrimaryImage = false,
    List<AttachmentRef>? images,
    List<AttachmentRef>? files,
  }) => NoteAttachments(
    primaryImage: clearPrimaryImage
        ? null
        : (primaryImage ?? this.primaryImage),
    images: images ?? this.images,
    files: files ?? this.files,
    preservedImages: preservedImages,
    preservedFiles: preservedFiles,
    extra: extra,
  );

  /// Vault paths of every vault entry, known or preserved, so GC / purge
  /// never deletes bytes a newer build still references.
  Set<String> get vaultPaths {
    final out = <String>{};
    for (final r in [?primaryImage, ...images, ...files]) {
      if (r is VaultRef) out.add(r.path);
    }
    void addRaw(Object? m) {
      if (m is Map && m['kind'] == 'vault') {
        final p = m['path'];
        if (p is String && p.isNotEmpty) out.add(p);
      }
    }

    preservedImages.forEach(addRaw);
    preservedFiles.forEach(addRaw);
    addRaw(extra['primaryImage']);
    return out;
  }

  static const _deep = DeepCollectionEquality();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NoteAttachments) return false;
    return other.primaryImage == primaryImage &&
        _deep.equals(other.images, images) &&
        _deep.equals(other.files, files) &&
        _deep.equals(other.preservedImages, preservedImages) &&
        _deep.equals(other.preservedFiles, preservedFiles) &&
        _deep.equals(other.extra, extra);
  }

  @override
  int get hashCode => Object.hash(
    primaryImage,
    _deep.hash(images),
    _deep.hash(files),
    _deep.hash(preservedImages),
    _deep.hash(preservedFiles),
    _deep.hash(extra),
  );

  @override
  String toString() =>
      'NoteAttachments(primaryImage: $primaryImage, '
      'images: $images, files: $files, preservedImages: $preservedImages, '
      'preservedFiles: $preservedFiles, extra: $extra)';
}
