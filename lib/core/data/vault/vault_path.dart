// Vault relative-path utility.
//
// The single source of truth lives in docs/attachments-path-spec.md
// in the Hmm repo. Any change here must be mirrored on the .NET side
// in Hmm.Core.Vault — otherwise client and server will disagree about
// which paths are valid and the vault will silently lose files.
//
// Pure functions, no I/O, no clock, no random.

const int _maxSegmentLength = 255;
const int _maxPathLength = 1024;

/// Reserved Windows device names — vault must remain syncable to NTFS
/// via OneDrive on a Windows host, so refuse these as whole segments
/// (case-insensitive match).
const Set<String> _windowsReservedNames = {
  'con', 'prn', 'aux', 'nul',
  'com1', 'com2', 'com3', 'com4', 'com5',
  'com6', 'com7', 'com8', 'com9',
  'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5',
  'lpt6', 'lpt7', 'lpt8', 'lpt9',
};

bool _isAllowedChar(int codeUnit) {
  // ASCII A-Z, a-z, 0-9, '-', '_', '.'  (nothing else)
  return (codeUnit >= 0x41 && codeUnit <= 0x5A) || // A-Z
      (codeUnit >= 0x61 && codeUnit <= 0x7A) || // a-z
      (codeUnit >= 0x30 && codeUnit <= 0x39) || // 0-9
      codeUnit == 0x2D || // -
      codeUnit == 0x5F || // _
      codeUnit == 0x2E; // .
}

void _validateSegment(String segment) {
  if (segment.isEmpty) {
    throw ArgumentError.value(segment, 'segment', 'empty segment');
  }
  if (segment.length > _maxSegmentLength) {
    throw ArgumentError.value(
      segment,
      'segment',
      'exceeds max segment length ($_maxSegmentLength)',
    );
  }
  if (segment == '.' || segment == '..') {
    throw ArgumentError.value(
      segment,
      'segment',
      'segment "$segment" not allowed (dot/parent)',
    );
  }
  if (_windowsReservedNames.contains(segment.toLowerCase())) {
    throw ArgumentError.value(
      segment,
      'segment',
      'segment is a reserved Windows device name',
    );
  }
  // Reject trailing '.' on a segment — Windows refuses to create such
  // files and silently strips the dot, which corrupts vault refs.
  if (segment.endsWith('.')) {
    throw ArgumentError.value(
      segment,
      'segment',
      'segment must not end with "."',
    );
  }
  for (final cu in segment.codeUnits) {
    if (!_isAllowedChar(cu)) {
      throw ArgumentError.value(
        segment,
        'segment',
        'disallowed character (code unit 0x${cu.toRadixString(16)})',
      );
    }
  }
}

/// Join [segments] into a vault relative path with POSIX `/`
/// separators after validating each segment in isolation.
///
/// A segment must not itself contain a separator — passing
/// `["a", "b/c"]` is a bug, not a convenience.
///
/// Throws [ArgumentError] on any rule violation.
String vaultRelativePathJoin(Iterable<String> segments) {
  final list = segments.toList(growable: false);
  if (list.isEmpty) {
    throw ArgumentError.value(
      segments,
      'segments',
      'at least one segment required',
    );
  }
  for (final s in list) {
    if (s.contains('/') || s.contains('\\')) {
      throw ArgumentError.value(
        s,
        'segment',
        'segment must not contain a separator',
      );
    }
    _validateSegment(s);
  }
  final joined = list.join('/');
  if (joined.length > _maxPathLength) {
    throw ArgumentError.value(
      joined,
      'path',
      'joined path exceeds max length ($_maxPathLength)',
    );
  }
  return joined;
}

/// Validate a full vault relative path. Returns the input unchanged
/// on success (the path is its own canonical form).
///
/// Throws [ArgumentError] on any rule violation.
String vaultRelativePathValidate(String path) {
  if (path.isEmpty) {
    throw ArgumentError.value(path, 'path', 'empty path');
  }
  if (path.length > _maxPathLength) {
    throw ArgumentError.value(
      path,
      'path',
      'exceeds max path length ($_maxPathLength)',
    );
  }
  if (path.contains('\\')) {
    throw ArgumentError.value(path, 'path', 'backslash not allowed');
  }
  if (path.startsWith('/')) {
    throw ArgumentError.value(path, 'path', 'leading slash not allowed');
  }
  // Trailing slash, doubled slashes, and empty segments are all caught
  // by _validateSegment's empty-segment check after splitting.
  final segments = path.split('/');
  for (final s in segments) {
    _validateSegment(s);
  }
  return path;
}
