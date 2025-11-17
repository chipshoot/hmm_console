import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScreenScaffold(
      title: 'Forgot Password',
      child: Center(
        child: Text(
          'Forgot Password Screen',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
