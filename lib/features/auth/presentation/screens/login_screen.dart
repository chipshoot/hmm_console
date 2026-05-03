import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/core/exceptions/app_exceptions.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/presentation/widges/user_pass_form.dart';
import 'package:hmm_console/features/auth/presentation/widges/welcome_text.dart';
import 'package:hmm_console/features/auth/states/login_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Captured on each form submit so the email-not-confirmed snackbar can
  // wire a "Resend email" action without asking the user to retype.
  String _lastEmail = '';

  @override
  Widget build(BuildContext context) {
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
        final isEmailNotConfirmed = error is AuthTokenException &&
            error.code == 'EMAIL_NOT_CONFIRMED';

        SnackBarAction? action;
        if (isInvalidCredentials) {
          action = SnackBarAction(
            label: 'Sign Up',
            onPressed: () {
              messenger.hideCurrentSnackBar();
              AppRouter.go(context, RouterNames.register);
            },
          );
        } else if (isEmailNotConfirmed && _lastEmail.isNotEmpty) {
          action = SnackBarAction(
            label: 'Resend email',
            onPressed: () async {
              messenger.hideCurrentSnackBar();
              await ref
                  .read(idpTokenServiceProvider)
                  .resendConfirmation(email: _lastEmail);
              if (!context.mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'If $_lastEmail is registered, we just sent a new verification link. Check your inbox.',
                  ),
                  duration: const Duration(seconds: 6),
                ),
              );
            },
          );
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isInvalidCredentials
                  ? '$message. New here? Sign up for an account.'
                  : message,
            ),
            action: action,
            // Email-not-confirmed is informational, not a recovery prompt —
            // give the user a few extra seconds to read it.
            duration: isInvalidCredentials || isEmailNotConfirmed
                ? const Duration(seconds: 6)
                : const Duration(seconds: 4),
          ),
        );
      }
    });
    return CommonScreenScaffold(
      title: 'Login',
      child: loginState.isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
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
                    _lastEmail = email;
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
