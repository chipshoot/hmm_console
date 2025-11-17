import 'package:flutter/material.dart';
import 'package:hmm_console/core/core.dart';
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
        children: <Widget> [
          const WelcomeText(),
          GapWidgets.h16,
          UserPassForm(
            String email,
            String password, 
            async {},),
          Text(
            'Welcome to Home made messaage!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16.0),
          Form(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget> [
                const WelcomeText(), TextField(
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16.0),
                const TextField(
                  decoration: InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () {
                    AppRouter.go(context, RouterNames.login);
                  },
                  child: const Text('Login'),
                ),
                const SizedBox(height: 16.0),
                TextButton(
                  onPressed: () {
                    AppRouter.go(context, RouterNames.register);
                  },
                  child: const Text('Register'),
                ),
                TextButton(
                  onPressed: () {
                    AppRouter.go(context, RouterNames.forgotPassword);
                  },
                  child: const Text('Forgot Password'),
                ),
              ],
            ),
          ),
          // Add your login form widgets here
        ],
      ),
    );
  }
}
