import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScreenScaffold(
      title: 'Forgot Password',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.lock_reset, size: 64),
            GapWidgets.h16,
            const Text(
              'Password Reset',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            GapWidgets.h16,
            const Text(
              'Password reset via the app is coming soon. '
              'Please visit the Hmm identity portal to reset your password.',
              textAlign: TextAlign.center,
            ),
            GapWidgets.h48,
          ],
        ),
      ),
    );
  }
}
