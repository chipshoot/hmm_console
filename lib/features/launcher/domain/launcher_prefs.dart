import 'dart:convert';

/// User-customizable launcher prefs: pinned [favorites] (destination
/// ids, ordered) and [aliases] (alias text -> destination id). Synced
/// across devices inside the SyncableSettings bundle.
class LauncherPrefs {
  const LauncherPrefs({this.favorites = const [], this.aliases = const {}});

  final List<String> favorites;
  final Map<String, String> aliases;

  static const empty = LauncherPrefs();

  LauncherPrefs copyWith({List<String>? favorites, Map<String, String>? aliases}) =>
      LauncherPrefs(
        favorites: favorites ?? this.favorites,
        aliases: aliases ?? this.aliases,
      );

  Map<String, dynamic> toJson() => {
        'favorites': favorites,
        'aliases': aliases,
      };

  /// Tolerant decode: wrong-typed entries are dropped (the bundle is
  /// synced opaquely across client versions, so never throw).
  factory LauncherPrefs.fromJson(Map<String, dynamic> json) {
    final favs = (json['favorites'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final aliases = <String, String>{};
    final rawAliases = json['aliases'];
    if (rawAliases is Map) {
      rawAliases.forEach((k, v) {
        if (k is String && v is String) aliases[k] = v;
      });
    }
    return LauncherPrefs(favorites: favs, aliases: aliases);
  }

  String toJsonString() => jsonEncode(toJson());

  factory LauncherPrefs.fromJsonString(String s) =>
      LauncherPrefs.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
