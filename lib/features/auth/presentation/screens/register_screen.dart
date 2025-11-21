import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/features/auth/presentation/widges/user_pass_form.dart';
import 'package:hmm_console/features/auth/presentation/widges/welcome_text.dart';
import 'package:hmm_console/features/auth/states/register_state.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              ref
                  .read(registerStateProvider.notifier)
                  .registerWithEmailPassword(email, password);
              // todo: handle register logic
            },
          ),
          GapWidgets.h48,
        ],
      ),
    );
  }
}
