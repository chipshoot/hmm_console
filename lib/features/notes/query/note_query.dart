/// Plain-data description of what the Notes list shows: a source, free text,
/// filter tokens, a scope and a sort. JSON is forward-compatible: anything a
/// newer client wrote that this one does not understand is kept and re-emitted.
library;

enum NoteSort { dateNewest, dateOldest, lastModified, subjectAZ, flagColor }

enum NoteScope { all, currentSource }

enum RelativeRange { last7d, last30d, last90d }

bool _deepEq(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? v) {
  if (v is Map) {
    return Object.hashAllUnordered(
      v.entries.map((e) => Object.hash(e.key, _deepHash(e.value))),
    );
  }
  if (v is List) return Object.hashAll(v.map(_deepHash));
  return v.hashCode;
}

Map<String, Object?> _asMap(Object? v) =>
    (v as Map).map((k, val) => MapEntry(k as String, val));

// ---------------------------------------------------------------- sources

sealed class NoteSource {
  const NoteSource();

  Map<String, Object?> toJson();

  static NoteSource fromJson(Object? json) {
    if (json is! Map) return const AllSource();
    final m = _asMap(json);
    try {
      switch (m['type']) {
        case 'all':
          return const AllSource();
        case 'pinned':
          return const PinnedSource();
        case 'flagged':
          return FlaggedSource(color: m['color'] as int?);
        case 'today':
          return const TodaySource();
        case 'domain':
          return DomainSource(
            key: m['key'] as String,
            catalogId: m['catalogId'] as int?,
          );
        case 'tag':
          return TagSource(tagId: m['tagId'] as int);
        case 'smart':
          return SmartSource(savedId: m['savedId'] as String);
        case 'recentlyDeleted':
          return const RecentlyDeletedSource();
      }
    } on TypeError {
      // Malformed known type: keep it whole rather than lose it.
    }
    return UnknownSource(raw: m);
  }
}

class AllSource extends NoteSource {
  const AllSource();
  @override
  Map<String, Object?> toJson() => {'type': 'all'};
  @override
  bool operator ==(Object other) => other is AllSource;
  @override
  int get hashCode => 'all'.hashCode;
}

class PinnedSource extends NoteSource {
  const PinnedSource();
  @override
  Map<String, Object?> toJson() => {'type': 'pinned'};
  @override
  bool operator ==(Object other) => other is PinnedSource;
  @override
  int get hashCode => 'pinned'.hashCode;
}

class FlaggedSource extends NoteSource {
  const FlaggedSource({this.color});
  final int? color;
  @override
  Map<String, Object?> toJson() => {
    'type': 'flagged',
    if (color != null) 'color': color,
  };
  @override
  bool operator ==(Object other) =>
      other is FlaggedSource && other.color == color;
  @override
  int get hashCode => Object.hash('flagged', color);
}

class TodaySource extends NoteSource {
  const TodaySource();
  @override
  Map<String, Object?> toJson() => {'type': 'today'};
  @override
  bool operator ==(Object other) => other is TodaySource;
  @override
  int get hashCode => 'today'.hashCode;
}

class DomainSource extends NoteSource {
  const DomainSource({required this.key, this.catalogId});
  final String key;
  final int? catalogId;
  @override
  Map<String, Object?> toJson() => {
    'type': 'domain',
    'key': key,
    if (catalogId != null) 'catalogId': catalogId,
  };
  @override
  bool operator ==(Object other) =>
      other is DomainSource && other.key == key && other.catalogId == catalogId;
  @override
  int get hashCode => Object.hash('domain', key, catalogId);
}

class TagSource extends NoteSource {
  const TagSource({required this.tagId});
  final int tagId;
  @override
  Map<String, Object?> toJson() => {'type': 'tag', 'tagId': tagId};
  @override
  bool operator ==(Object other) => other is TagSource && other.tagId == tagId;
  @override
  int get hashCode => Object.hash('tag', tagId);
}

class SmartSource extends NoteSource {
  const SmartSource({required this.savedId});
  final String savedId;
  @override
  Map<String, Object?> toJson() => {'type': 'smart', 'savedId': savedId};
  @override
  bool operator ==(Object other) =>
      other is SmartSource && other.savedId == savedId;
  @override
  int get hashCode => Object.hash('smart', savedId);
}

class RecentlyDeletedSource extends NoteSource {
  const RecentlyDeletedSource();
  @override
  Map<String, Object?> toJson() => {'type': 'recentlyDeleted'};
  @override
  bool operator ==(Object other) => other is RecentlyDeletedSource;
  @override
  int get hashCode => 'recentlyDeleted'.hashCode;
}

class UnknownSource extends NoteSource {
  const UnknownSource({required this.raw});
  final Map<String, Object?> raw;
  @override
  Map<String, Object?> toJson() => raw;
  @override
  bool operator ==(Object other) =>
      other is UnknownSource && _deepEq(other.raw, raw);
  @override
  int get hashCode => _deepHash(raw);
}

// ----------------------------------------------------------------- tokens

sealed class NoteToken {
  const NoteToken();

  Map<String, Object?> toJson();

  static NoteToken fromJson(Object? json) {
    if (json is! Map) return UnknownToken({'raw': json});
    final m = _asMap(json);
    try {
      switch (m['type']) {
        case 'tag':
          return TagToken(m['tagId'] as int);
        case 'flag':
          return FlagToken(m['color'] as int);
        case 'domain':
          return DomainToken(m['key'] as String);
        case 'catalog':
          return CatalogToken(m['catalogId'] as int);
        case 'parent':
          return ParentToken(m['noteUuid'] as String);
        case 'hasPhoto':
          return const HasPhotoToken();
        case 'hasPlace':
          return const HasPlaceToken();
        case 'hasAttachment':
          return const HasAttachmentToken();
        case 'date':
          return DateRangeToken(
            from: _parseDate(m['from']),
            to: _parseDate(m['to']),
          );
        case 'relativeDate':
          final range = RelativeRange.values.asNameMap()[m['range']];
          if (range != null) return RelativeDateToken(range);
        case 'pinned':
          return const PinnedToken();
      }
    } on TypeError {
      // Malformed known type: keep it whole rather than lose it.
    }
    return UnknownToken(m);
  }

  static DateTime? _parseDate(Object? v) =>
      v is String ? DateTime.parse(v).toUtc() : null;
}

class TagToken extends NoteToken {
  const TagToken(this.tagId);
  final int tagId;
  @override
  Map<String, Object?> toJson() => {'type': 'tag', 'tagId': tagId};
  @override
  bool operator ==(Object other) => other is TagToken && other.tagId == tagId;
  @override
  int get hashCode => Object.hash('tag', tagId);
}

class FlagToken extends NoteToken {
  const FlagToken(this.color);
  final int color;
  @override
  Map<String, Object?> toJson() => {'type': 'flag', 'color': color};
  @override
  bool operator ==(Object other) => other is FlagToken && other.color == color;
  @override
  int get hashCode => Object.hash('flag', color);
}

class DomainToken extends NoteToken {
  const DomainToken(this.key);
  final String key;
  @override
  Map<String, Object?> toJson() => {'type': 'domain', 'key': key};
  @override
  bool operator ==(Object other) => other is DomainToken && other.key == key;
  @override
  int get hashCode => Object.hash('domain', key);
}

class CatalogToken extends NoteToken {
  const CatalogToken(this.catalogId);
  final int catalogId;
  @override
  Map<String, Object?> toJson() => {'type': 'catalog', 'catalogId': catalogId};
  @override
  bool operator ==(Object other) =>
      other is CatalogToken && other.catalogId == catalogId;
  @override
  int get hashCode => Object.hash('catalog', catalogId);
}

class ParentToken extends NoteToken {
  const ParentToken(this.noteUuid);
  final String noteUuid;
  @override
  Map<String, Object?> toJson() => {'type': 'parent', 'noteUuid': noteUuid};
  @override
  bool operator ==(Object other) =>
      other is ParentToken && other.noteUuid == noteUuid;
  @override
  int get hashCode => Object.hash('parent', noteUuid);
}

class HasPhotoToken extends NoteToken {
  const HasPhotoToken();
  @override
  Map<String, Object?> toJson() => {'type': 'hasPhoto'};
  @override
  bool operator ==(Object other) => other is HasPhotoToken;
  @override
  int get hashCode => 'hasPhoto'.hashCode;
}

class HasPlaceToken extends NoteToken {
  const HasPlaceToken();
  @override
  Map<String, Object?> toJson() => {'type': 'hasPlace'};
  @override
  bool operator ==(Object other) => other is HasPlaceToken;
  @override
  int get hashCode => 'hasPlace'.hashCode;
}

class HasAttachmentToken extends NoteToken {
  const HasAttachmentToken();
  @override
  Map<String, Object?> toJson() => {'type': 'hasAttachment'};
  @override
  bool operator ==(Object other) => other is HasAttachmentToken;
  @override
  int get hashCode => 'hasAttachment'.hashCode;
}

class DateRangeToken extends NoteToken {
  const DateRangeToken({this.from, this.to});
  final DateTime? from;
  final DateTime? to;
  @override
  Map<String, Object?> toJson() => {
    'type': 'date',
    if (from != null) 'from': from!.toUtc().toIso8601String(),
    if (to != null) 'to': to!.toUtc().toIso8601String(),
  };
  @override
  bool operator ==(Object other) =>
      other is DateRangeToken && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash('date', from, to);
}

class RelativeDateToken extends NoteToken {
  const RelativeDateToken(this.range);
  final RelativeRange range;
  @override
  Map<String, Object?> toJson() => {
    'type': 'relativeDate',
    'range': range.name,
  };
  @override
  bool operator ==(Object other) =>
      other is RelativeDateToken && other.range == range;
  @override
  int get hashCode => Object.hash('relativeDate', range);
}

class PinnedToken extends NoteToken {
  const PinnedToken();
  @override
  Map<String, Object?> toJson() => {'type': 'pinned'};
  @override
  bool operator ==(Object other) => other is PinnedToken;
  @override
  int get hashCode => 'pinned'.hashCode;
}

class UnknownToken extends NoteToken {
  const UnknownToken(this.raw);
  final Map<String, Object?> raw;
  @override
  Map<String, Object?> toJson() => raw;
  @override
  bool operator ==(Object other) =>
      other is UnknownToken && _deepEq(other.raw, raw);
  @override
  int get hashCode => _deepHash(raw);
}

// ------------------------------------------------------------------ query

class NoteQuery {
  const NoteQuery({
    this.source = const AllSource(),
    this.text = '',
    this.tokens = const [],
    this.scope = NoteScope.currentSource,
    this.sort = NoteSort.dateNewest,
    this.extra = const {},
    String? rawScope,
    String? rawSort,
  }) : _rawScope = rawScope,
       _rawSort = rawSort;

  const NoteQuery.initial() : this();

  factory NoteQuery.fromJson(Map<String, Object?> json) {
    const known = {'source', 'text', 'tokens', 'scope', 'sort'};
    final scopeRaw = json['scope'];
    final sortRaw = json['sort'];
    final scope = NoteScope.values.asNameMap()[scopeRaw];
    final sort = NoteSort.values.asNameMap()[sortRaw];
    return NoteQuery(
      source: NoteSource.fromJson(json['source']),
      text: json['text'] as String? ?? '',
      tokens: [
        for (final t in (json['tokens'] as List?) ?? const <Object?>[])
          NoteToken.fromJson(t),
      ],
      scope: scope ?? NoteScope.currentSource,
      sort: sort ?? NoteSort.dateNewest,
      extra: {
        for (final e in json.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
      rawScope: scope == null && scopeRaw is String ? scopeRaw : null,
      rawSort: sort == null && sortRaw is String ? sortRaw : null,
    );
  }

  final NoteSource source;
  final String text;
  final List<NoteToken> tokens;
  final NoteScope scope;
  final NoteSort sort;

  /// Unknown top-level fields from a newer client, re-emitted verbatim.
  final Map<String, Object?> extra;

  // An unrecognised scope/sort string, kept so it survives until the user
  // changes that setting.
  final String? _rawScope;
  final String? _rawSort;

  NoteQuery copyWith({
    NoteSource? source,
    String? text,
    List<NoteToken>? tokens,
    NoteScope? scope,
    NoteSort? sort,
  }) => NoteQuery(
    source: source ?? this.source,
    text: text ?? this.text,
    tokens: tokens ?? this.tokens,
    scope: scope ?? this.scope,
    sort: sort ?? this.sort,
    extra: extra,
    rawScope: scope == null ? _rawScope : null,
    rawSort: sort == null ? _rawSort : null,
  );

  Map<String, Object?> toJson() => {
    ...extra,
    'source': source.toJson(),
    'text': text,
    'tokens': [for (final t in tokens) t.toJson()],
    'scope': _rawScope ?? scope.name,
    'sort': _rawSort ?? sort.name,
  };

  @override
  bool operator ==(Object other) =>
      other is NoteQuery &&
      other.source == source &&
      other.text == text &&
      _deepEq(other.tokens, tokens) &&
      other.scope == scope &&
      other.sort == sort &&
      other._rawScope == _rawScope &&
      other._rawSort == _rawSort &&
      _deepEq(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    source,
    text,
    Object.hashAll(tokens),
    scope,
    sort,
    _rawScope,
    _rawSort,
    _deepHash(extra),
  );
}
