import 'dart:convert';

import '../../../core/data/attachments/attachment_ref.dart';

/// Pulls a *piece* out of a note: a scalar field, a markdown section, the
/// whole body, or one image attachment.
///
/// There is no catalog field-schema on the client (the `schema` column is
/// never parsed), so field binding works by introspecting the note's content
/// JSON into dotted leaf paths.
///
/// Nothing here throws — a malformed note yields an empty list or null, so a
/// bad reference degrades to a placeholder instead of taking down a screen.
class NotePieceExtractor {
  /// The inner entity map of the storage envelope
  /// `{"note":{"content":{<Entity>:{...}}}}`.
  /// Deliberately unlogged: this runs once per field lookup — several times
  /// per card render — so a malformed note would flood the log on every
  /// frame. `LocalCheatsheetRepository._deserialize` logs the same class of
  /// failure once per note, with the note's id and uuid attached, which is
  /// the diagnosable version.
  static Map<String, dynamic>? _entityMap(String? content) {
    if (content == null) return null;
    try {
      final inner = (jsonDecode(content) as Map)['note']?['content'];
      return inner is Map ? inner.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// True when the entity map carries `isActivated: false` (a soft-deleted
  /// note). Never throws; anything unreadable counts as active.
  static bool isDeactivated(String? content) {
    final root = _entityMap(content);
    if (root == null) return false;
    for (final v in root.values) {
      if (v is Map && v['isActivated'] == false) return true;
    }
    return false;
  }

  static const _internalKeys = {
    '_v',
    'id',
    'uuid',
    'authorId',
    'parentNoteId',
    'version',
    'schemaVersion',
    'isSelf',
    'isActivated',
  };
  /// `Id$` hides foreign keys; `Path$` hides the vault paths that entity
  /// notes (e.g. `DriverLicence.frontImagePath`) keep in content to point at
  /// their attachments. Bound as text, such a field printed `images/…jpg`
  /// where the photo should be — the image is offered through [images].
  static final _internalPattern = RegExp(r'^_|Id$|Path$');
  static final _timestampPattern = RegExp(r'(date|at)$', caseSensitive: false);

  static bool _isInternal(String segment) =>
      _internalKeys.contains(segment) ||
      _internalPattern.hasMatch(segment) ||
      _timestampPattern.hasMatch(segment);

  /// Bindable leaf paths to *offer* in the designer.
  ///
  /// Internal and audit keys are filtered out: exposing `id`, `uuid` or
  /// `createdDate` as bindable card rows leaks plumbing into a user-facing
  /// surface. This is an offer policy only — [field] deliberately still
  /// resolves any explicit path, so tightening this list can never break a
  /// binding somebody already made.
  ///
  /// A curated, catalog-keyed adapter registry is the v2 replacement; this
  /// filter mitigates but does not remove the serializer-shape brittleness.
  static List<String> fieldPaths(String? content) {
    final root = _entityMap(content);
    if (root == null) return const [];
    final out = <String>[];

    void walk(String prefix, Map<String, dynamic> m) {
      for (final e in m.entries) {
        if (_isInternal(e.key)) continue;
        final path = prefix.isEmpty ? e.key : '$prefix.${e.key}';
        final v = e.value;
        if (v is Map) {
          walk(path, v.cast<String, dynamic>());
        } else if (v is List) {
          // Only a non-empty list of maps (a contact's phones) is walked, by
          // index. Scalar, mixed and empty lists stay skipped.
          if (v.isNotEmpty && v.every((x) => x is Map)) {
            for (var i = 0; i < v.length; i++) {
              walk('$path.$i', (v[i] as Map).cast<String, dynamic>());
            }
          }
        } else {
          out.add(path);
        }
      }
    }

    walk('', root);
    return out;
  }

  /// The scalar at a dotted [path], or null if absent or non-scalar.
  static String? field(String? content, String path) {
    dynamic node = _entityMap(content);
    for (final seg in path.split('.')) {
      if (node is Map && node.containsKey(seg)) {
        node = node[seg];
      } else if (node is List) {
        final i = int.tryParse(seg);
        if (i == null || i < 0 || i >= node.length) return null;
        node = node[i];
      } else {
        return null;
      }
    }
    if (node == null || node is Map || node is List) return null;
    return node.toString();
  }

  static final _heading = RegExp(r'^#{1,6}\s+');

  static List<String> sectionHeadings(String? md) => md == null
      ? const []
      : md
          .split('\n')
          .where(_heading.hasMatch)
          .map((l) => l.replaceFirst(_heading, '').trim())
          .toList();

  /// The block under [heading], up to the next heading or the end.
  static String? section(String? md, String heading) {
    if (md == null) return null;
    final lines = md.split('\n');
    final start = lines.indexWhere((l) =>
        _heading.hasMatch(l) && l.replaceFirst(_heading, '').trim() == heading);
    if (start < 0) return null;
    final body = <String>[];
    for (var i = start + 1; i < lines.length; i++) {
      if (_heading.hasMatch(lines[i])) break;
      body.add(lines[i]);
    }
    return body.join('\n').trim();
  }

  /// The whole note, as something worth putting on a card.
  ///
  /// A human-written description is used verbatim. Otherwise the note is
  /// entity-backed, and returning its raw `content` would print the storage
  /// envelope — `{"note":{"content":{...}}}` complete with `id`, `uuid` and
  /// `createdDate` — straight onto a user-facing card. That is exactly the
  /// plumbing [fieldPaths] exists to keep out of the binding list, so this
  /// summarises the same filtered fields instead.
  static String whole(String? content, String? description) {
    if (description != null && description.trim().isNotEmpty) {
      return description;
    }

    final lines = <String>[];
    for (final path in fieldPaths(content)) {
      final value = field(content, path);
      if (value == null || value.isEmpty) continue;
      lines.add('${_labelFor(path)}: $value');
    }
    return lines.join('\n');
  }

  /// Drops the entity root from a dotted path: `GasLog.nested.x` -> `nested.x`.
  static String _labelFor(String path) {
    final firstDot = path.indexOf('.');
    return firstDot < 0 ? path : path.substring(firstDot + 1);
  }

  /// The note's image attachments, in display order: primary, gallery, then
  /// image-typed files (a document scan is stored as a file). Vault refs only
  /// — a vault path is the one identity that survives a sync to another
  /// device, which is what a card row needs to address it by.
  static List<VaultRef> images(NoteAttachments? attachments) {
    if (attachments == null) return const [];
    return [
      if (attachments.primaryImage case final VaultRef p) p,
      ...attachments.images.whereType<VaultRef>(),
      ...attachments.files.whereType<VaultRef>(),
    ].where((r) => r.contentType.startsWith('image/')).toList();
  }

  /// The image at vault [path] on [attachments], or null if it is gone.
  static VaultRef? image(NoteAttachments? attachments, String path) {
    for (final r in images(attachments)) {
      if (r.path == path) return r;
    }
    return null;
  }

  /// A human name for [ref]: the content key that points at it
  /// (`frontImagePath` -> `frontImage`), else its file name.
  static String imageLabel(String? content, VaultRef ref) {
    String? found;
    void walk(Map<String, dynamic> m) {
      for (final e in m.entries) {
        if (found != null) return;
        final v = e.value;
        if (v is Map) {
          walk(v.cast<String, dynamic>());
        } else if (v == ref.path) {
          found = e.key.endsWith('Path')
              ? e.key.substring(0, e.key.length - 4)
              : e.key;
        }
      }
    }

    final root = _entityMap(content);
    if (root != null) walk(root);
    return found ?? ref.originalName ?? ref.path.split('/').last;
  }
}
