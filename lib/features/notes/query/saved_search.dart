/// A named, ordered [NoteQuery] the user keeps. Synced in the settings bundle;
/// fields a newer client wrote that this one does not know are kept in
/// [extra] and re-emitted.
library;

import 'package:flutter/foundation.dart';

import 'note_query.dart';

class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.order,
    required this.query,
    this.extra = const {},
  });

  final String id;
  final String name;
  final int order;
  final NoteQuery query;

  /// Unknown fields, re-emitted by [toJson].
  final Map<String, Object?> extra;

  static const _known = {'id', 'name', 'order', 'query'};

  factory SavedSearch.fromJson(Map<String, Object?> json) {
    final q = json['query'];
    final order = json['order'];
    return SavedSearch(
      id: json['id'] as String,
      name: json['name'] as String,
      order: order is num ? order.toInt() : 0,
      query: q is Map
          ? NoteQuery.fromJson(q.map((k, v) => MapEntry(k as String, v)))
          : const NoteQuery.initial(),
      extra: {
        for (final e in json.entries)
          if (!_known.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, Object?> toJson() => {
    ...extra,
    'id': id,
    'name': name,
    'order': order,
    'query': query.toJson(),
  };

  SavedSearch copyWith({String? name, int? order}) => SavedSearch(
    id: id,
    name: name ?? this.name,
    order: order ?? this.order,
    query: query,
    extra: extra,
  );
}

/// Parses a decoded JSON list; entries without a String `id` and `name` (or
/// that are not maps) are skipped. Anything else yields an empty list.
List<SavedSearch> parseSavedSearches(Object? json) {
  if (json is! List) return const [];
  final out = <SavedSearch>[];
  for (final e in json) {
    if (e is! Map) continue;
    if (e['id'] is! String || e['name'] is! String) continue;
    if (e.keys.any((k) => k is! String)) continue;
    try {
      out.add(SavedSearch.fromJson(e.map((k, v) => MapEntry(k as String, v))));
    } catch (err) {
      // One corrupt entry must not lose the rest. Type only: user content.
      debugPrint('SavedSearches: skipped entry (${err.runtimeType})');
    }
  }
  return out;
}
