import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/features/auth/domain/logics/email_pass_validator.dart';

class ForgotPasswordScreen extends StatelessWidget with EmailPassValidator {
  ForgotPasswordScreen({super.key});
  final TextEditingController emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CommonScreenScaffold(
      title: 'Forgot Password',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('Reset Your Password'),
          GapWidgets.h8,
          AppTextFormField(
            fieldController: emailController,
            fieldValidator: validateEmail,
            label: 'Email',
          ),
          GapWidgets.h48,
        ],
      ),
    );
  }
}
