import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/core/exceptions/app_exceptions.dart';
import 'package:hmm_console/features/auth/presentation/screens/register_screen.dart';
import 'package:hmm_console/features/auth/states/register_state.dart';

/// Drives the register form through a failed attempt (loading -> error)
/// without touching the use case, mirroring a "no connection" failure.
class _FailingRegisterState extends RegisterState {
  @override
  Future<void> registerWithEmailPassword(
    String username,
    String email,
    String password,
    String confirmPassword,
  ) async {
    state = const AsyncValue.loading();
    state =
        AsyncValue.error(NetworkException.noConnection(), StackTrace.current);
  }
}

void main() {
  testWidgets('entered sign-up fields survive a failed registration attempt',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          registerStateProvider.overrideWith(() => _FailingRegisterState()),
        ],
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // username, email, password, confirm — in field order.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'newuser');
    await tester.enterText(fields.at(1), 'new@example.com');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.enterText(fields.at(3), 'secret123');
    await tester.pump();

    await tester.tap(find.widgetWithText(HighlightButton, 'Sign Up'));
    await tester.pumpAndSettle();

    // After the failed attempt the form returns; nothing the user typed
    // should have been wiped (regression guard mirroring the login fix).
    final editables =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(editables.length, 4);
    expect(editables[0].controller.text, 'newuser');
    expect(editables[1].controller.text, 'new@example.com');
    expect(editables[2].controller.text, 'secret123');
    expect(editables[3].controller.text, 'secret123');
  });
}
