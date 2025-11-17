import 'package:flutter/material.dart';

class AppTextFormField extends StatelessWidget {
  final TextEditingController fieldController;
  final String label;
  final bool obscureText;

  const AppTextFormField({
    super.key,
    required this.fieldController,
    required this.label,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: fieldController,
      obscureText: obscureText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      //validator: (value) {
      //  if (value == null || value.isEmpty) {
      //    return 'Please enter your $label';
      //  }
      //  return null;
      //},
    );
  }
}
