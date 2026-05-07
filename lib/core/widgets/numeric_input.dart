import 'package:flutter/services.dart';

/// Shared configuration for numeric form fields. Use as:
/// ```dart
/// AppTextFormField(
///   ...,
///   keyboardType: NumericInput.decimal.keyboardType,
///   inputFormatters: NumericInput.decimal.formatters,
/// );
/// ```
///
/// On iOS the number pad has no Done/Return key by design — pair these
/// fields with a `GestureDetector(onTap: () => FocusScope.of(context)
/// .unfocus())` wrap on the parent form so users can dismiss by tapping
/// outside.
class NumericInput {
  const NumericInput._({
    required this.keyboardType,
    required this.formatters,
  });

  final TextInputType keyboardType;
  final List<TextInputFormatter> formatters;

  /// Integer-only input (year, mileage, percentage…). Strips letters and
  /// punctuation; allows arbitrary digit count.
  static final integer = NumericInput._(
    keyboardType: const TextInputType.numberWithOptions(decimal: false),
    formatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
  );

  /// Decimal input (fuel volume, prices, MPG…). Allows digits + at most one
  /// '.'; rejects letters and additional dots from paste.
  static final decimal = NumericInput._(
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    formatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      _SingleDecimalPointFormatter(),
    ],
  );
}

class _SingleDecimalPointFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if ('.'.allMatches(newValue.text).length <= 1) return newValue;
    return oldValue;
  }
}
