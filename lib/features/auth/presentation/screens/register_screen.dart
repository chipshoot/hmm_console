import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      } else if (next.hasValue && next.value == true && prev?.value != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registration successful! Please check your email to verify your account, then log in.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    });

    return CommonScreenScaffold(
      title: 'Sign Up',
      child: registerState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const WelcomeText(),
                  GapWidgets.h16,
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppTextFormField(
                          fieldController: _usernameController,
                          fieldValidator: _validateUsername,
                          label: 'Username',
                        ),
                        GapWidgets.h8,
                        AppTextFormField(
                          fieldController: _emailController,
                          fieldValidator: validateEmail,
                          label: 'Email',
                        ),
                        GapWidgets.h8,
                        AppTextFormField(
                          fieldController: _passwordController,
                          fieldValidator: validatePassword,
                          obscureText: true,
                          label: 'Password',
                        ),
                        GapWidgets.h8,
                        AppTextFormField(
                          fieldController: _confirmPasswordController,
                          fieldValidator: _validateConfirmPassword,
                          obscureText: true,
                          label: 'Confirm Password',
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
