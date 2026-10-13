import 'package:flutter/widgets.dart' show StringCharacters;

/// The twelve hand-picked colour themes. Stored by [Enum.name]; a stored
/// value this version does not know renders as the template default and is
/// written back unchanged (see [CardStyle]).
enum CardThemeId {
  blue,
  green,
  orange,
  red,
  purple,
  teal,
  pink,
  amber,
  slate,
  indigo,
  brown,
  black,
}

/// Drawn over the theme colour. [none] is the default and is never stored.
enum CardPattern { none, dots, stripes, grid, waves }

/// How the detail screen lays out rows: [facts] (label -> value, the original
/// layout) or [keyPoints] (numbered, theme-coloured, optional row emoji).
enum CardLayout { facts, keyPoints }

/// The look a template gives a card whose style says nothing.
class CardLookDefaults {
  const CardLookDefaults({
    required this.theme,
    required this.icon,
    required this.layout,
  });

  final CardThemeId theme;
  final String icon;
  final CardLayout layout;

  // Escapes, not literals: "is this the default icon?" is a byte comparison
  // (a default is never stored), and an editor silently dropping the U+FE0F
  // variation selector from a literal would break it.
  static const car = '\u{1F697}'; // car
  static const medical = '⚕️'; // staff of Aesculapius
  static const book = '\u{1F4D6}'; // open book
  static const dividers = '\u{1F5C2}️'; // card index dividers

  static CardLookDefaults of(String templateId) => switch (templateId) {
        'accidentClaim' => const CardLookDefaults(
            theme: CardThemeId.blue, icon: car, layout: CardLayout.facts),
        'healthInfo' => const CardLookDefaults(
            theme: CardThemeId.green, icon: medical, layout: CardLayout.facts),
        'document' => const CardLookDefaults(
            theme: CardThemeId.orange,
            icon: book,
            layout: CardLayout.keyPoints),
        _ => const CardLookDefaults(
            theme: CardThemeId.slate, icon: dividers, layout: CardLayout.facts),
      };
}

/// The look a card actually renders with: stored values where they are
/// valid, template defaults everywhere else.
class CardLook {
  const CardLook({
    required this.theme,
    required this.pattern,
    required this.icon,
    required this.layout,
  });

  final CardThemeId theme;
  final CardPattern pattern;
  final String icon;
  final CardLayout layout;
}

/// A card's `style` block, kept as the raw map it was read from.
///
/// Holding the raw map rather than typed fields is what makes preservation
/// free: a newer theme name, a wrong-typed value, or a key this version has
/// never heard of is simply carried along and written back, because nothing
/// ever re-derives the map from typed fields. An edit replaces one key in
/// place (keeping key order, so an untouched style stays byte-identical) and
/// removes it instead when the new value is the template default.
class CardStyle {
  const CardStyle([this._raw = const {}]);

  static const empty = CardStyle();

  static const themeKey = 'theme';
  static const patternKey = 'pattern';
  static const iconKey = 'icon';
  static const layoutKey = 'layout';
  static const coverKey = 'cover';

  final Map<String, dynamic> _raw;

  bool get isEmpty => _raw.isEmpty;

  /// A copy, in stored key order.
  Map<String, dynamic> toMap() => Map<String, dynamic>.of(_raw);

  CardThemeId? get theme => _byName(CardThemeId.values, _raw[themeKey]);
  CardPattern? get pattern => _byName(CardPattern.values, _raw[patternKey]);
  CardLayout? get layout => _byName(CardLayout.values, _raw[layoutKey]);

  /// The stored icon text, valid or not. Rendering goes through [resolve].
  String? get icon {
    final v = _raw[iconKey];
    return v is String ? v : null;
  }

  /// Vault path of the cover attachment, if any. The bytes are referenced
  /// from the note's `attachments` column, never from here.
  String? get coverPath {
    final v = _raw[coverKey];
    return v is String && v.isNotEmpty ? v : null;
  }

  CardStyle withTheme(CardThemeId t, {required String templateId}) => _with(
      themeKey, t == CardLookDefaults.of(templateId).theme ? null : t.name);

  CardStyle withPattern(CardPattern p) =>
      _with(patternKey, p == CardPattern.none ? null : p.name);

  CardStyle withIcon(String? icon, {required String templateId}) => _with(
      iconKey,
      icon == null ||
              icon.isEmpty ||
              icon == CardLookDefaults.of(templateId).icon
          ? null
          : icon);

  CardStyle withLayout(CardLayout l, {required String templateId}) => _with(
      layoutKey, l == CardLookDefaults.of(templateId).layout ? null : l.name);

  CardStyle withCoverPath(String? path) =>
      _with(coverKey, path == null || path.isEmpty ? null : path);

  CardLook resolve(String templateId) {
    final d = CardLookDefaults.of(templateId);
    final i = icon;
    return CardLook(
      theme: theme ?? d.theme,
      pattern: pattern ?? CardPattern.none,
      icon: i != null && isSingleEmoji(i) ? i : d.icon,
      layout: layout ?? d.layout,
    );
  }

  /// Replaces [key] where it already sits (order matters for byte identity),
  /// appends it when new, and removes it when [value] is null.
  CardStyle _with(String key, Object? value) {
    final next = <String, dynamic>{};
    var placed = false;
    for (final e in _raw.entries) {
      if (e.key == key) {
        placed = true;
        if (value != null) next[key] = value;
      } else {
        next[e.key] = e.value;
      }
    }
    if (!placed && value != null) next[key] = value;
    return CardStyle(next);
  }

  static T? _byName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardStyle && jsonValueEquals(_raw, other._raw);

  @override
  int get hashCode => jsonValueHash(_raw);

  @override
  String toString() => 'CardStyle(keys: ${_raw.keys.toList()})';
}

/// One emoji: exactly one grapheme cluster whose first code point is an
/// emoji (so skin tones, ZWJ sequences and flags count as one), or a keycap.
bool isSingleEmoji(String s) {
  if (s.isEmpty || s.characters.length != 1) return false;
  final runes = s.runes.toList();
  if (runes.contains(0x20E3)) return true; // keycap: #, *, 0-9 + U+20E3
  final r = runes.first;
  return (r >= 0x1F000 && r <= 0x1FAFF) ||
      (r >= 0x2600 && r <= 0x27BF) ||
      (r >= 0x2300 && r <= 0x23FF) ||
      (r >= 0x2B00 && r <= 0x2BFF) ||
      (r >= 0x2190 && r <= 0x21FF) ||
      r == 0x203C ||
      r == 0x2049 ||
      r == 0x2122 ||
      r == 0x2139 ||
      r == 0x3030 ||
      r == 0x303D ||
      r == 0x3297 ||
      r == 0x3299;
}

/// Structural equality for decoded JSON. Map key ORDER counts: these values
/// are written back to storage, where order is part of byte identity.
bool jsonValueEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    final ka = a.keys.toList();
    final kb = b.keys.toList();
    for (var i = 0; i < ka.length; i++) {
      if (ka[i] != kb[i] || !jsonValueEquals(a[ka[i]], b[kb[i]])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonValueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int jsonValueHash(Object? v) {
  if (v is Map) {
    return Object.hashAll([
      for (final e in v.entries) Object.hash(e.key, jsonValueHash(e.value)),
    ]);
  }
  if (v is List) return Object.hashAll(v.map(jsonValueHash));
  return v.hashCode;
}
