import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/features/auth/presentation/widges/social_login.dart';
import 'package:hmm_console/features/auth/presentation/widges/user_pass_form.dart';
import 'package:hmm_console/features/auth/presentation/widges/welcome_text.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScreenScaffold(
      title: 'Login',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const WelcomeText(),
          GapWidgets.h16,
          UserPassForm(
            buttonLabel: 'Login',
            onFormSubmit: (String email, String password) async {},
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text("Don't have an account?"),
              TextButton(
                onPressed: () {
                  AppRouter.go(context, RouterNames.register);
                },
                child: const Text('Sign Up'),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Forgot your password?'),
              TextButton(
                onPressed: () {
                  AppRouter.go(context, RouterNames.forgotPassword);
                },
                child: const Text('Forgot Password'),
              ),
            ],
          ),
          GapWidgets.h8,
          const Text('Or login with'),
          const SocialLogin(),
          // Add your login form widgets here
        ],
      ),
    );
  }
}
