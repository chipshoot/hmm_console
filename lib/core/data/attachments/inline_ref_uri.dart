/// Custom URI scheme for inline note images. The content string carries only
/// these text placeholders; the bytes stay in the vault.
const String _scheme = 'hmm-attachment://';
const String _pendingPrefix = 'pending/';

/// `attachments/note-1/x.png` -> `hmm-attachment://attachments/note-1/x.png`.
String formatImageUri(String vaultPath) => '$_scheme$vaultPath';

/// The vault path for a real (non-pending) image URI, else null.
String? parseImageUri(String uri) {
  if (!uri.startsWith(_scheme)) return null;
  final rest = uri.substring(_scheme.length);
  if (rest.isEmpty || rest.startsWith(_pendingPrefix)) return null;
  return rest;
}

/// `abc` -> `hmm-attachment://pending/abc`.
String formatPendingUri(String uuid) => '$_scheme$_pendingPrefix$uuid';

/// The uuid for a pending URI, else null.
String? pendingUuidOf(String uri) {
  if (!uri.startsWith(_scheme)) return null;
  final rest = uri.substring(_scheme.length);
  if (!rest.startsWith(_pendingPrefix)) return null;
  final uuid = rest.substring(_pendingPrefix.length);
  return uuid.isEmpty ? null : uuid;
}

// Markdown image: ![alt](url) — capture the url up to the first whitespace or
// close-paren, so a `![a](url "title")` form yields the bare url (matching how
// the renderer parses `config.uri`). App-generated vault paths never contain
// spaces, so this is lossless for our content.
final RegExp _imageMd = RegExp(r'!\[[^\]]*\]\(([^)\s]+)');

Iterable<String> _inlineUrls(String markdown) =>
    _imageMd.allMatches(markdown).map((m) => m.group(1)!);

/// All real inline image vault paths, in document order.
List<String> imageRefPathsIn(String markdown) => _inlineUrls(markdown)
    .map(parseImageUri)
    .whereType<String>()
    .toList();

/// All pending uuids referenced inline, in document order.
List<String> pendingUuidsIn(String markdown) => _inlineUrls(markdown)
    .map(pendingUuidOf)
    .whereType<String>()
    .toList();

/// Replace every `pending/<uuid>` image URI with its real vault image URI.
String rewritePendingToVault(String markdown, Map<String, String> uuidToPath) {
  var out = markdown;
  uuidToPath.forEach((uuid, path) {
    out = out.replaceAll(formatPendingUri(uuid), formatImageUri(path));
  });
  return out;
}

/// Removes the whole `![alt](hmm-attachment://pending/<uuid>)` image markdown
/// for [uuid] — used to strip a placeholder whose bytes failed to persist so no
/// `pending/` URI is ever written into saved note content.
String removePendingImage(String markdown, String uuid) {
  final re = RegExp(
      r'!\[[^\]]*\]\(' + RegExp.escape(formatPendingUri(uuid)) + r'\)');
  return markdown.replaceAll(re, '');
}

const String _noteScheme = 'hmm-note://';

/// `abc` -> `hmm-note://abc`.
String formatNoteUri(String uuid) => '$_noteScheme$uuid';

/// The note uuid for a `hmm-note://<uuid>` link (any `#anchor` is dropped —
/// anchors are a reserved future feature), else null.
String? parseNoteUri(String uri) {
  if (!uri.startsWith(_noteScheme)) return null;
  var rest = uri.substring(_noteScheme.length);
  final hash = rest.indexOf('#');
  if (hash >= 0) rest = rest.substring(0, hash);
  return rest.isEmpty ? null : rest;
}

// Markdown link (not image): [text](url) — a leading '!' would make it an image.
final RegExp _linkMd = RegExp(r'(?<!\!)\[[^\]]*\]\(([^)\s]+)');

/// All inline `hmm-note://` link uuids, in document order.
List<String> noteUuidsIn(String markdown) => _linkMd
    .allMatches(markdown)
    .map((m) => m.group(1)!)
    .map(parseNoteUri)
    .whereType<String>()
    .toList();
