import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';

void main() {
  group('AttachmentRefCodec — round-trip', () {
    test('VaultRef survives toJson → fromJson', () {
      const ref = VaultRef(
        path: 'attachments/note-5/9c8a-photo.jpg',
        originalName: 'old-photo.jpg',
        contentType: 'image/jpeg',
        byteSize: 423112,
      );
      final json = AttachmentRefCodec.toJson(ref);
      expect(json['kind'], equals('vault'));
      expect(json['byteSize'], equals(423112));
      expect(AttachmentRefCodec.fromJson(json), equals(ref));
    });

    test('VaultRef without originalName omits the key', () {
      const ref = VaultRef(
        path: 'attachments/note-1/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      );
      final json = AttachmentRefCodec.toJson(ref);
      expect(json.containsKey('originalName'), isFalse);
      expect(AttachmentRefCodec.fromJson(json), equals(ref));
    });

    test('PhAssetRef survives toJson → fromJson (with byteSize)', () {
      const ref = PhAssetRef(
        id: 'ABC-123-DEF/L0/001',
        originalName: 'IMG_2031.HEIC',
        contentType: 'image/heic',
        byteSize: 423112,
      );
      final json = AttachmentRefCodec.toJson(ref);
      expect(json['kind'], equals('phasset'));
      expect(AttachmentRefCodec.fromJson(json), equals(ref));
    });

    test('PhAssetRef without byteSize round-trips with null', () {
      const ref = PhAssetRef(
        id: 'ABC-123-DEF/L0/001',
        contentType: 'image/heic',
      );
      final json = AttachmentRefCodec.toJson(ref);
      expect(json.containsKey('byteSize'), isFalse);
      expect(AttachmentRefCodec.fromJson(json), equals(ref));
      expect((AttachmentRefCodec.fromJson(json) as PhAssetRef).byteSize, isNull);
    });

    test('CloudFileRef survives toJson → fromJson', () {
      const ref = CloudFileRef(
        provider: CloudProvider.oneDrive,
        path: 'Pictures/Cars/IMG_2031.jpg',
        originalName: 'IMG_2031.jpg',
        contentType: 'image/jpeg',
        byteSize: 423112,
      );
      final json = AttachmentRefCodec.toJson(ref);
      expect(json['kind'], equals('cloudFile'));
      expect(json['provider'], equals('oneDrive'));
      expect(AttachmentRefCodec.fromJson(json), equals(ref));
    });

    test('CloudFileRef accepts spaces and accents in its path', () {
      // Cloud folders are real OS paths; they're not vault paths.
      const ref = CloudFileRef(
        provider: CloudProvider.iCloudDrive,
        path: 'My Photos/Vacaciones 2024/foto.jpg',
        contentType: 'image/jpeg',
      );
      final json = AttachmentRefCodec.toJson(ref);
      expect(AttachmentRefCodec.fromJson(json), equals(ref));
    });
  });

  group('AttachmentRefCodec — rejections', () {
    test('rejects unknown kind', () {
      expect(
        () => AttachmentRefCodec.fromJson(
          {'kind': 'magic', 'path': 'x.jpg', 'contentType': 'image/jpeg', 'byteSize': 1},
        ),
        throwsFormatException,
      );
    });

    test('rejects missing kind', () {
      expect(
        () => AttachmentRefCodec.fromJson(
          {'path': 'x.jpg', 'contentType': 'image/jpeg', 'byteSize': 1},
        ),
        throwsFormatException,
      );
    });

    test('rejects vault ref with disallowed contentType', () {
      expect(
        () => AttachmentRefCodec.fromJson({
          'kind': 'vault',
          'path': 'a.bmp',
          'contentType': 'image/bmp',
          'byteSize': 1,
        }),
        throwsFormatException,
      );
    });

    test('rejects vault ref with bad path (parent segment)', () {
      expect(
        () => AttachmentRefCodec.fromJson({
          'kind': 'vault',
          'path': '../escape.jpg',
          'contentType': 'image/jpeg',
          'byteSize': 1,
        }),
        throwsFormatException,
      );
    });

    test('rejects vault ref with bad path (backslash)', () {
      expect(
        () => AttachmentRefCodec.fromJson({
          'kind': 'vault',
          'path': r'attachments\note-1\x.jpg',
          'contentType': 'image/jpeg',
          'byteSize': 1,
        }),
        throwsFormatException,
      );
    });

    test('rejects vault ref with missing byteSize', () {
      expect(
        () => AttachmentRefCodec.fromJson({
          'kind': 'vault',
          'path': 'a.jpg',
          'contentType': 'image/jpeg',
        }),
        throwsFormatException,
      );
    });

    test('rejects vault ref with negative byteSize', () {
      expect(
        () => AttachmentRefCodec.fromJson({
          'kind': 'vault',
          'path': 'a.jpg',
          'contentType': 'image/jpeg',
          'byteSize': -1,
        }),
        throwsFormatException,
      );
    });

    test('rejects phasset ref with missing id', () {
      expect(
        () => AttachmentRefCodec.fromJson({
          'kind': 'phasset',
          'contentType': 'image/heic',
        }),
        throwsFormatException,
      );
    });

    test('rejects cloudFile ref with unknown provider', () {
      expect(
        () => AttachmentRefCodec.fromJson({
          'kind': 'cloudFile',
          'provider': 'dropbox',
          'path': 'a.jpg',
          'contentType': 'image/jpeg',
        }),
        throwsFormatException,
      );
    });
  });

  group('NoteAttachmentsCodec — round-trip', () {
    test('encodes empty payload as null (caller stores SQL NULL)', () {
      final encoded = NoteAttachmentsCodec.encode(NoteAttachments.empty);
      expect(encoded, isNull);
    });

    test('decodes null/empty as empty payload', () {
      expect(NoteAttachmentsCodec.decode(null), equals(NoteAttachments.empty));
      expect(NoteAttachmentsCodec.decode(''), equals(NoteAttachments.empty));
    });

    test('primary-only payload round-trips', () {
      const primary = VaultRef(
        path: 'attachments/note-7/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      );
      final payload = NoteAttachments(primaryImage: primary);
      final encoded = NoteAttachmentsCodec.encode(payload);
      expect(encoded, isNotNull);
      final decoded = NoteAttachmentsCodec.decode(encoded);
      expect(decoded, equals(payload));
      expect(decoded.primaryImage, equals(primary));
      expect(decoded.images, isEmpty);
    });

    test('gallery-only payload round-trips and preserves order', () {
      final payload = NoteAttachments(
        images: const [
          VaultRef(
            path: 'attachments/note-1/a.jpg',
            contentType: 'image/jpeg',
            byteSize: 1,
          ),
          PhAssetRef(id: 'PH-1', contentType: 'image/heic'),
          CloudFileRef(
            provider: CloudProvider.oneDrive,
            path: 'Pictures/b.png',
            contentType: 'image/png',
          ),
        ],
      );
      final decoded = NoteAttachmentsCodec.decode(
        NoteAttachmentsCodec.encode(payload),
      );
      expect(decoded, equals(payload));
      expect(decoded.images.map((r) => r.kind),
          equals(['vault', 'phasset', 'cloudFile']));
    });

    test('mixed primary + gallery payload round-trips', () {
      final payload = NoteAttachments(
        primaryImage: const VaultRef(
          path: 'attachments/note-5/primary.jpg',
          contentType: 'image/jpeg',
          byteSize: 200,
        ),
        images: const [
          VaultRef(
            path: 'attachments/note-5/extra-1.jpg',
            contentType: 'image/jpeg',
            byteSize: 50,
          ),
          VaultRef(
            path: 'attachments/note-5/extra-2.jpg',
            contentType: 'image/jpeg',
            byteSize: 75,
          ),
        ],
      );
      expect(
        NoteAttachmentsCodec.decode(NoteAttachmentsCodec.encode(payload)),
        equals(payload),
      );
    });

    test('encoded column value matches the design-doc shape', () {
      const primary = VaultRef(
        path: 'attachments/note-5/primary.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      );
      final encoded = NoteAttachmentsCodec.encode(
        NoteAttachments(primaryImage: primary),
      );
      final parsed = jsonDecode(encoded!) as Map<String, dynamic>;
      expect(parsed.containsKey('primaryImage'), isTrue);
      expect(parsed['primaryImage']['kind'], equals('vault'));
      expect(parsed['primaryImage']['path'], equals(primary.path));
      expect(parsed['images'], isA<List<dynamic>>());
      expect(parsed['images'], isEmpty);
    });
  });

  group('NoteAttachmentsCodec — rejections', () {
    test('rejects malformed JSON', () {
      expect(
        () => NoteAttachmentsCodec.decode('{not-json'),
        throwsFormatException,
      );
    });

    test('rejects a non-object root', () {
      expect(
        () => NoteAttachmentsCodec.decode('[1,2,3]'),
        throwsFormatException,
      );
    });

    test('rejects "images" that is not an array', () {
      expect(
        () => NoteAttachmentsCodec.decode('{"images": {}}'),
        throwsFormatException,
      );
    });

    test('rejects primaryImage that is not an object', () {
      expect(
        () => NoteAttachmentsCodec.decode('{"primaryImage": "nope"}'),
        throwsFormatException,
      );
    });

    test('rejects an image that is not an object', () {
      expect(
        () => NoteAttachmentsCodec.decode('{"images": ["nope"]}'),
        throwsFormatException,
      );
    });
  });

  group('NoteAttachments — disjointness', () {
    test('constructor throws if primaryImage also appears in images', () {
      const dup = VaultRef(
        path: 'attachments/note-1/dup.jpg',
        contentType: 'image/jpeg',
        byteSize: 1,
      );
      expect(
        () => NoteAttachments(primaryImage: dup, images: const [dup]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('codec surfaces a disjointness violation as a FormatException', () {
      // Hand-crafted payload that duplicates the primary in the
      // gallery — a buggy older client might emit this.
      const refJson = {
        'kind': 'vault',
        'path': 'attachments/note-1/dup.jpg',
        'contentType': 'image/jpeg',
        'byteSize': 1,
      };
      final payload = jsonEncode({
        'primaryImage': refJson,
        'images': [refJson],
      });
      expect(
        () => NoteAttachmentsCodec.decode(payload),
        throwsFormatException,
      );
    });
  });
}
