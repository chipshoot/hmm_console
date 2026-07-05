import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/core/exceptions/app_exceptions.dart';
import 'package:hmm_console/features/auth/presentation/screens/login_screen.dart';
import 'package:hmm_console/features/auth/states/login_state.dart';

/// Drives the login form through a failed attempt (loading -> error) without
/// touching repositories, mirroring the real "no connection" failure.
class _FailingLoginState extends LoginState {
  @override
  Future<void> loginWithEmailPassword(String email, String password) async {
    state = const AsyncValue.loading();
    state =
        AsyncValue.error(NetworkException.noConnection(), StackTrace.current);
  }
}

void main() {
  testWidgets(
      'entered email/password survive a failed login (form is not wiped)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginStateProvider.overrideWith(() => _FailingLoginState()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Type credentials into the email + password fields.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'user@example.com');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.pump();

    // Tap Login -> loading -> error -> the form is rebuilt.
    await tester.tap(find.widgetWithText(HighlightButton, 'Login'));
    await tester.pumpAndSettle();

    // After the failed attempt the form returns; the credentials the user
    // (or iCloud Keychain autofill) put in must still be there.
    final editables =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(editables.length, 2,
        reason: 'both fields should be back after the error');
    expect(editables[0].controller.text, 'user@example.com');
    expect(editables[1].controller.text, 'secret123');
  });
}
