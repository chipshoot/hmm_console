import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/features/auth/domain/logics/email_pass_validator.dart';

class UserPassForm extends StatelessWidget with EmailPassValidator {
  final String buttonLabel;
  final Function(String, String) onFormSubmit;
  final VoidCallback? onFieldInteraction;

  // create a global key that will uniquely identity the form
  final _formKey = GlobalKey<FormState>();

  UserPassForm({
    super.key,
    required this.buttonLabel,
    required this.onFormSubmit,
    this.onFieldInteraction,
  });

  @override
  Widget build(BuildContext context) {
    // Implementation of the form goes here
    final userNameController = TextEditingController();
    final passwordController = TextEditingController();
    return Form(
      key: _formKey,
      // AutofillGroup tells iOS / Android to treat the email + password
      // pair as a single credential record. Without it, iCloud Keychain
      // saves them separately and never offers paired autofill.
      child: AutofillGroup(
        child: Column(
          children: <Widget>[
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) onFieldInteraction?.call();
              },
              child: AppTextFormField(
                fieldController: userNameController,
                fieldValidator: validateEmail,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
              ),
            ),
            GapWidgets.h8,
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) onFieldInteraction?.call();
              },
              child: AppTextFormField(
                fieldController: passwordController,
                fieldValidator: validatePassword,
                obscureText: true,
                label: 'Password',
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
              ),
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
      ),
    );
  }
}
