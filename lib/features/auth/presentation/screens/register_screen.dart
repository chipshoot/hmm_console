import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/features/auth/presentation/widges/user_pass_form.dart';
import 'package:hmm_console/features/auth/presentation/widges/welcome_text.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScreenScaffold(
      title: 'Sign Up',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const WelcomeText(),
          GapWidgets.h48,
          UserPassForm(
            buttonLabel: 'Sign Up',
            onFormSubmit: (String email, String password) {
              // todo: handle register logic
            },
          ),
          GapWidgets.h48,
        ],
      ),
    );
  }
}
