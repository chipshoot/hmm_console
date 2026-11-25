import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/navigation/auth_change_provider.dart';
import 'package:hmm_console/core/navigation/login_gate.dart';
import 'package:hmm_console/core/settings/app_settings.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';

class _FixedSettings extends SettingsController {
  _FixedSettings(this._settings);
  final AppSettings? _settings;

  @override
  Future<AppSettings> build() => _settings == null
      ? Completer<AppSettings>().future
      : Future.value(_settings);
}

Future<bool> _loginRequired({
  required DataMode mode,
  required bool signedIn,
  bool settingsLoaded = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        () => _FixedSettings(
          settingsLoaded ? AppSettings.defaults.copyWith(dataMode: mode) : null,
        ),
      ),
      routerAuthStateProvider.overrideWith((_) => Stream.value(signedIn)),
    ],
  );
  addTearDown(container.dispose);
  final authSub = container.listen(routerAuthStateProvider, (_, _) {});
  addTearDown(authSub.close);
  final gateSub = container.listen(loginRequiredProvider, (_, _) {});
  addTearDown(gateSub.close);
  await container.read(routerAuthStateProvider.future);
  if (settingsLoaded) await container.read(settingsProvider.future);
  await container.pump();
  return container.read(loginRequiredProvider);
}

void main() {
  group('loginRequiredProvider', () {
    test('local, signed out: no login needed', () async {
      expect(
        await _loginRequired(mode: DataMode.local, signedIn: false),
        isFalse,
      );
    });

    test('cloudStorage, signed out: no login needed', () async {
      expect(
        await _loginRequired(mode: DataMode.cloudStorage, signedIn: false),
        isFalse,
      );
    });

    test('cloudApi, signed out: login needed', () async {
      expect(
        await _loginRequired(mode: DataMode.cloudApi, signedIn: false),
        isTrue,
      );
    });

    test('cloudApi, signed in: no login needed', () async {
      expect(
        await _loginRequired(mode: DataMode.cloudApi, signedIn: true),
        isFalse,
      );
    });

    test('settings not loaded yet: holds off', () async {
      expect(
        await _loginRequired(
          mode: DataMode.cloudApi,
          signedIn: false,
          settingsLoaded: false,
        ),
        isFalse,
      );
    });
  });

  group('authGateRedirect', () {
    test('sends to /auth when a login is required', () {
      expect(authGateRedirect(loginRequired: true, isAuthPath: false), '/auth');
    });

    test('does not loop on /auth', () {
      expect(authGateRedirect(loginRequired: true, isAuthPath: true), isNull);
    });

    test('leaves everyone alone when no login is required', () {
      for (final onAuth in [true, false]) {
        expect(
          authGateRedirect(loginRequired: false, isAuthPath: onAuth),
          isNull,
        );
      }
    });
  });
}
