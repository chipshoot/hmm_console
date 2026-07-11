import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextFormField extends StatelessWidget {
  final TextEditingController fieldController;
  final String? Function(String?) fieldValidator;
  final String label;
  final bool obscureText;

  /// Hints the OS uses to offer iCloud Keychain / Google Password Manager
  /// autofill. For paired credentials (email + password), wrap the parent
  /// form in an `AutofillGroup` so the OS treats them as a single record.
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Restricts what characters can be typed/pasted into the field. Useful
  /// in tandem with `keyboardType: TextInputType.numberWithOptions(...)` to
  /// stop letters from sneaking in via paste on Android.
  final List<TextInputFormatter>? inputFormatters;

  /// Optional helper text shown under the field (e.g. "Supports markdown").
  final String? helperText;

  /// Fires on every edit — used e.g. to drive a live markdown preview.
  final ValueChanged<String>? onChanged;

  const AppTextFormField({
    super.key,
    required this.fieldController,
    required this.fieldValidator,
    required this.label,
    this.obscureText = false,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.helperText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: fieldController,
      obscureText: obscureText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: OutlineInputBorder(),
      ),
      validator: fieldValidator,
    );
  }
}
