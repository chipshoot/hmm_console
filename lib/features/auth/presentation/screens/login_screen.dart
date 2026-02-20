import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/core/exceptions/app_exceptions.dart';
import 'package:hmm_console/features/auth/presentation/widges/user_pass_form.dart';
import 'package:hmm_console/features/auth/presentation/widges/welcome_text.dart';
import 'package:hmm_console/features/auth/states/login_state.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginState = ref.watch(loginStateProvider);
    final messenger = ScaffoldMessenger.of(context);
    ref.listen(loginStateProvider, (prev, next) {
      if (next.isLoading || next.hasValue) {
        messenger.hideCurrentSnackBar();
      }
      if (next.hasError) {
        final error = next.error;
        final message =
            error is AppException ? error.message : 'Something went wrong';
        final isInvalidCredentials = error is AuthTokenException &&
            error.code == 'INVALID_CREDENTIALS';

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isInvalidCredentials
                  ? '$message. New here? Sign up for an account.'
                  : message,
            ),
            action: isInvalidCredentials
                ? SnackBarAction(
                    label: 'Sign Up',
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      AppRouter.go(context, RouterNames.register);
                    },
                  )
                : null,
            duration: isInvalidCredentials
                ? const Duration(seconds: 6)
                : const Duration(seconds: 4),
          ),
        );
      }
    });
    return CommonScreenScaffold(
      title: 'Login',
      child: loginState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const WelcomeText(),
                GapWidgets.h16,
                UserPassForm(
                  buttonLabel: 'Login',
                  onFieldInteraction: () => messenger.clearSnackBars(),
                  onFormSubmit: (String email, String password) async {
                    messenger.clearSnackBars();
                    ref
                        .read(loginStateProvider.notifier)
                        .loginWithEmailPassword(email, password);
                  },
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
              ],
            ),
    );
  }
}
