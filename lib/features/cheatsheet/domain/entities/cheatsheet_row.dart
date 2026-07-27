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
  });

  final String label;

  /// Null = unbound.
  final CheatsheetSource? source;

  /// Explicit — see [ValueAction]. Never inferred.
  final ValueAction valueAction;

  /// Whether the detail screen offers "open the source note".
  final bool openSource;

  bool get isBound => source != null;

  /// Pass [clearSource] to unbind — a null [source] argument can't express
  /// "remove the binding" because null already means "leave unchanged".
  CheatsheetRow copyWith({
    String? label,
    CheatsheetSource? source,
    bool clearSource = false,
    ValueAction? valueAction,
    bool? openSource,
  }) =>
      CheatsheetRow(
        label: label ?? this.label,
        source: clearSource ? null : (source ?? this.source),
        valueAction: valueAction ?? this.valueAction,
        openSource: openSource ?? this.openSource,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheatsheetRow &&
        other.label == label &&
        other.source == source &&
        other.valueAction == valueAction &&
        other.openSource == openSource;
  }

  @override
  int get hashCode => Object.hash(label, source, valueAction, openSource);

  @override
  String toString() => 'CheatsheetRow(label: $label, source: $source, '
      'valueAction: ${valueAction.name}, openSource: $openSource)';
}
