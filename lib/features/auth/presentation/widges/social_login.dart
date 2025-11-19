import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';

class SocialLogin extends StatelessWidget {
  const SocialLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        OutlinedButton(
          onPressed: () {
            // Handle Twitter login
          },
          child: const Text('Google'),
        ),
        GapWidgets.w16,
        OutlinedButton(
          onPressed: () {
            // Handle Twitter login
          },
          child: const Text('Apple'),
        ),
      ],
    );
  }
}
