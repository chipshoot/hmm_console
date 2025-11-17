import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';

class UserPassForm extends StatelessWidget {
  final String buttonLabel;
  final Function(String, String) onFormSubmit;

  // create a global key that will uniquely identity the form
  final _formKey = GlobalKey<FormState>();

  UserPassForm({
    super.key,
    required this.buttonLabel,
    required this.onFormSubmit,
  });

  @override
  Widget build(BuildContext context) {
    // Implementation of the form goes here
    final userNameController = TextEditingController();
    final passwordController = TextEditingController();
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          AppTextFormField(
            fieldController: userNameController,
            label: 'Username',
          ),
          GapWidgets.h8,
          AppTextFormField(
            fieldController: passwordController,
            obscureText: true,
            label: 'Password',
          ),
          GapWidgets.h24,
          HighlightButton(
            text: buttonLabel,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                onFormSubmit(userNameController.text, passwordController.text);
              }
            },
          ),
        ],
      ),
    ); // Placeholder
  }
}
