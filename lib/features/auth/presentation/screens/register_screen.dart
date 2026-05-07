import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/features/auth/domain/logics/email_pass_validator.dart';
import 'package:hmm_console/features/auth/presentation/widges/welcome_text.dart';
import 'package:hmm_console/features/auth/states/register_state.dart';

class RegisterScreen extends ConsumerWidget with EmailPassValidator {
  RegisterScreen({super.key});

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registerState = ref.watch(registerStateProvider);

    ref.listen(registerStateProvider, (prev, next) {
      if (next.isLoading) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      } else if (next.hasValue && next.value == true && prev?.value != true) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registration successful! Please check your email to verify your account, then log in.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        // Use go_router's go() to land on /auth deterministically, regardless
        // of how the user reached this screen (push from login, deep-link,
        // hot-restart, etc.). Navigator.pop() is unreliable across nested
        // GoRoute hierarchies — silently no-ops if the imperative stack is
        // empty even though GoRouter still has /auth/register as the location.
        context.go('/auth');
      }
    });

    return CommonScreenScaffold(
      title: 'Sign Up',
      child: registerState.isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const WelcomeText(),
                  GapWidgets.h16,
                  Form(
                    key: _formKey,
                    // AutofillGroup pairs the email + new-password fields
                    // so iCloud Keychain / Google Password Manager prompts
                    // to save them as one credential. AutofillHints.newPassword
                    // (vs .password) tells the OS this is a sign-up flow —
                    // it'll suggest a strong password instead of offering
                    // existing ones.
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          AppTextFormField(
                            fieldController: _usernameController,
                            fieldValidator: _validateUsername,
                            label: 'Username',
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newUsername],
                          ),
                          GapWidgets.h8,
                          AppTextFormField(
                            fieldController: _emailController,
                            fieldValidator: validateEmail,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                          ),
                          GapWidgets.h8,
                          AppTextFormField(
                            fieldController: _passwordController,
                            fieldValidator: validatePassword,
                            obscureText: true,
                            label: 'Password',
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                          ),
                          GapWidgets.h8,
                          AppTextFormField(
                            fieldController: _confirmPasswordController,
                            fieldValidator: _validateConfirmPassword,
                            obscureText: true,
                            label: 'Confirm Password',
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                          ),
                          GapWidgets.h8,
                          Text(
                            'Password must be at least 12 characters with uppercase, '
                            'lowercase, digit, and special character.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          GapWidgets.h24,
                          HighlightButton(
                            text: 'Sign Up',
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                ref
                                    .read(registerStateProvider.notifier)
                                    .registerWithEmailPassword(
                                      _usernameController.text,
                                      _emailController.text,
                                      _passwordController.text,
                                      _confirmPasswordController.text,
                                    );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  GapWidgets.h48,
                ],
              ),
            ),
    );
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }
}
