import 'card_style.dart';
import 'cheatsheet_source.dart';

/// One labelled line of a cheatsheet card.
///
/// A row may be **unbound** ([source] is null) — the designer allows saving a
/// partially bound card, and the detail screen renders an unbound row as a
/// muted placeholder rather than an error.
class CheatsheetRow {
  const CheatsheetRow({
    required this.label,
    required this.source,
    this.valueAction = ValueAction.none,
    this.openSource = true,
    this.emoji,
    this.extraFields = const {},
  });

  final String label;

  /// Null = unbound.
  final CheatsheetSource? source;

  /// Explicit — see [ValueAction]. Never inferred.
  final ValueAction valueAction;

  /// Whether the detail screen offers "open the source note".
  final bool openSource;

  /// Shown beside the label in the Key points layout. Stored as typed, valid
  /// or not; rendering checks it with `isSingleEmoji`.
  final String? emoji;

  /// Row keys this version does not model, written back unchanged so a save
  /// cannot destroy what a newer client stored.
  final Map<String, dynamic> extraFields;

  bool get isBound => source != null;

  /// Pass [clearSource] to unbind and [clearEmoji] to drop the emoji — a null
  /// argument can't express "remove" because null already means "leave
  /// unchanged".
  CheatsheetRow copyWith({
    String? label,
    CheatsheetSource? source,
    bool clearSource = false,
    ValueAction? valueAction,
    bool? openSource,
    String? emoji,
    bool clearEmoji = false,
    Map<String, dynamic>? extraFields,
  }) =>
      CheatsheetRow(
        label: label ?? this.label,
        source: clearSource ? null : (source ?? this.source),
        valueAction: valueAction ?? this.valueAction,
        openSource: openSource ?? this.openSource,
        emoji: clearEmoji ? null : (emoji ?? this.emoji),
        extraFields: extraFields ?? this.extraFields,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheatsheetRow &&
        other.label == label &&
        other.source == source &&
        other.valueAction == valueAction &&
        other.openSource == openSource &&
        other.emoji == emoji &&
        jsonValueEquals(other.extraFields, extraFields);
  }

  @override
  int get hashCode => Object.hash(label, source, valueAction, openSource,
      emoji, jsonValueHash(extraFields));

  @override
  String toString() => 'CheatsheetRow(label: $label, source: $source, '
      'valueAction: ${valueAction.name}, openSource: $openSource, '
      'emoji: ${emoji != null}, extraKeys: ${extraFields.keys.toList()})';
}
