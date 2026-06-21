// JSON codec for AttachmentRef and the NoteAttachments column wrapper.
//
// Mirrors src/Hmm.Core/Schemas/NoteAttachments.schema.json. The codec
// is the only place client code constructs AttachmentRefs from
// untrusted input; if a payload comes back invalid, the codec throws
// FormatException with a precise reason — never silently coerces.
//
// Disjointness ({primaryImage} ∉ {images}) is enforced by
// NoteAttachments' constructor; the codec surfaces the underlying
// ArgumentError as a FormatException.

import 'dart:convert';

import '../vault/vault_path.dart';
import 'attachment_ref.dart';

/// MIME types accepted in v1. Must match the schema's `contentType`
/// enum.
const Set<String> _allowedContentTypes = {
  'image/jpeg',
  'image/png',
  'image/heic',
  'image/webp',
  // Phase 3a: non-image file attachments.
  'application/pdf',
  // Phase 3b: voice recordings.
  'audio/mp4',
};

const int _maxOriginalNameLength = 500;
const int _maxIdLength = 256;
const int _maxPathLength = 1024;

void _requireMap(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$label: expected an object, got ${value.runtimeType}');
  }
}

String _requireString(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is! String || v.isEmpty) {
    throw FormatException('Missing or invalid string field "$key"');
  }
  return v;
}

String? _optionalString(
  Map<String, dynamic> json,
  String key, {
  required int maxLength,
}) {
  final v = json[key];
  if (v == null) return null;
  if (v is! String || v.isEmpty) {
    throw FormatException('"$key" must be a non-empty string when present');
  }
  if (v.length > maxLength) {
    throw FormatException('"$key" exceeds max length $maxLength');
  }
  return v;
}

String _validateContentType(String value) {
  if (!_allowedContentTypes.contains(value)) {
    throw FormatException(
      'contentType "$value" is not allowed (expected one of '
      '${_allowedContentTypes.toList()..sort()})',
    );
  }
  return value;
}

int _requireByteSize(Map<String, dynamic> json) {
  final v = json['byteSize'];
  if (v is! int || v < 0) {
    throw FormatException('"byteSize" must be a non-negative integer');
  }
  return v;
}

int? _optionalByteSize(Map<String, dynamic> json) {
  final v = json['byteSize'];
  if (v == null) return null;
  if (v is! int || v < 0) {
    throw FormatException(
      '"byteSize" must be a non-negative integer when present',
    );
  }
  return v;
}

/// Codec for a single [AttachmentRef].
class AttachmentRefCodec {
  const AttachmentRefCodec._();

  /// Parse a single ref from a JSON object. Throws [FormatException]
  /// on any shape or value violation.
  static AttachmentRef fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind is! String) {
      throw const FormatException('AttachmentRef: missing "kind"');
    }
    return switch (kind) {
      'vault' => _vaultFromJson(json),
      'phasset' => _phAssetFromJson(json),
      'cloudFile' => _cloudFileFromJson(json),
      _ => throw FormatException('Unknown AttachmentRef kind: "$kind"'),
    };
  }

  /// Serialize a single ref to a JSON object.
  static Map<String, dynamic> toJson(AttachmentRef ref) => switch (ref) {
        final VaultRef v => _vaultToJson(v),
        final PhAssetRef p => _phAssetToJson(p),
        final CloudFileRef c => _cloudFileToJson(c),
      };

  static VaultRef _vaultFromJson(Map<String, dynamic> j) {
    final path = _requireString(j, 'path');
    // Validate against the shared path spec — keeps client and server
    // in lockstep about which paths are even legal. The validator
    // throws ArgumentError on violation; convert to FormatException so
    // callers get one error type for "bad input."
    try {
      vaultRelativePathValidate(path);
    } on ArgumentError catch (e) {
      throw FormatException('vault "path" invalid: ${e.message}');
    }
    return VaultRef(
      path: path,
      originalName:
          _optionalString(j, 'originalName', maxLength: _maxOriginalNameLength),
      contentType: _validateContentType(_requireString(j, 'contentType')),
      byteSize: _requireByteSize(j),
    );
  }

  static Map<String, dynamic> _vaultToJson(VaultRef r) => {
        'kind': 'vault',
        'path': r.path,
        if (r.originalName != null) 'originalName': r.originalName,
        'contentType': r.contentType,
        'byteSize': r.byteSize,
      };

  static PhAssetRef _phAssetFromJson(Map<String, dynamic> j) {
    final id = _requireString(j, 'id');
    if (id.length > _maxIdLength) {
      throw FormatException('"id" exceeds max length $_maxIdLength');
    }
    return PhAssetRef(
      id: id,
      originalName:
          _optionalString(j, 'originalName', maxLength: _maxOriginalNameLength),
      contentType: _validateContentType(_requireString(j, 'contentType')),
      byteSize: _optionalByteSize(j),
    );
  }

  static Map<String, dynamic> _phAssetToJson(PhAssetRef r) => {
        'kind': 'phasset',
        'id': r.id,
        if (r.originalName != null) 'originalName': r.originalName,
        'contentType': r.contentType,
        if (r.byteSize != null) 'byteSize': r.byteSize,
      };

  static CloudFileRef _cloudFileFromJson(Map<String, dynamic> j) {
    final path = _requireString(j, 'path');
    // Cloud-folder paths live on the user's machine; they legitimately
    // contain spaces, accents, and so on — so the vault-path rules
    // don't apply here. We only enforce length + non-empty.
    if (path.length > _maxPathLength) {
      throw FormatException('"path" exceeds max length $_maxPathLength');
    }
    return CloudFileRef(
      provider: CloudProvider.fromWire(_requireString(j, 'provider')),
      path: path,
      originalName:
          _optionalString(j, 'originalName', maxLength: _maxOriginalNameLength),
      contentType: _validateContentType(_requireString(j, 'contentType')),
      byteSize: _optionalByteSize(j),
    );
  }

  static Map<String, dynamic> _cloudFileToJson(CloudFileRef r) => {
        'kind': 'cloudFile',
        'provider': r.provider.wireName,
        'path': r.path,
        if (r.originalName != null) 'originalName': r.originalName,
        'contentType': r.contentType,
        if (r.byteSize != null) 'byteSize': r.byteSize,
      };
}

/// Codec for the `Notes.attachments` JSON column value (the
/// `{primaryImage, images}` wrapper).
class NoteAttachmentsCodec {
  const NoteAttachmentsCodec._();

  /// Decode a column value. Pass `null` for a SQL-NULL column (which
  /// returns [NoteAttachments.empty]).
  static NoteAttachments decode(String? raw) {
    if (raw == null || raw.isEmpty) return NoteAttachments.empty;
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException('NoteAttachments: invalid JSON — ${e.message}');
    }
    _requireMap(parsed, 'NoteAttachments root');
    return fromJson(parsed! as Map<String, dynamic>);
  }

  /// Encode a payload back to a JSON string suitable for the column.
  /// Returns `null` for an empty payload — the caller should store
  /// SQL NULL.
  static String? encode(NoteAttachments value) {
    if (value.isEmpty) return null;
    return jsonEncode(toJson(value));
  }

  /// Parse from an already-decoded JSON object.
  static NoteAttachments fromJson(Map<String, dynamic> json) {
    AttachmentRef? primary;
    if (json.containsKey('primaryImage') && json['primaryImage'] != null) {
      _requireMap(json['primaryImage'], 'primaryImage');
      primary =
          AttachmentRefCodec.fromJson(json['primaryImage'] as Map<String, dynamic>);
    }

    var images = const <AttachmentRef>[];
    final imagesRaw = json['images'];
    if (imagesRaw != null) {
      if (imagesRaw is! List) {
        throw const FormatException('"images" must be an array');
      }
      images = imagesRaw.map((e) {
        if (e is! Map<String, dynamic>) {
          throw const FormatException('each image must be an object');
        }
        return AttachmentRefCodec.fromJson(e);
      }).toList(growable: false);
    }

    var files = const <AttachmentRef>[];
    final filesRaw = json['files'];
    if (filesRaw != null) {
      if (filesRaw is! List) {
        throw const FormatException('"files" must be an array');
      }
      files = filesRaw.map((e) {
        if (e is! Map<String, dynamic>) {
          throw const FormatException('each file must be an object');
        }
        return AttachmentRefCodec.fromJson(e);
      }).toList(growable: false);
    }

    try {
      return NoteAttachments(
          primaryImage: primary, images: images, files: files);
    } on ArgumentError catch (e) {
      // Surface disjointness as a FormatException so callers handle
      // one error type for bad input.
      throw FormatException('NoteAttachments: ${e.message}');
    }
  }

  /// Serialize to a JSON object. `files` is omitted when empty so existing
  /// images-only payloads stay byte-identical to pre-Phase-3a.
  static Map<String, dynamic> toJson(NoteAttachments value) => {
        if (value.primaryImage != null)
          'primaryImage': AttachmentRefCodec.toJson(value.primaryImage!),
        'images':
            value.images.map(AttachmentRefCodec.toJson).toList(growable: false),
        if (value.files.isNotEmpty)
          'files':
              value.files.map(AttachmentRefCodec.toJson).toList(growable: false),
      };
}
