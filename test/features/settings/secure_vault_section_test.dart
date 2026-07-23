import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart'
    show vaultKeyServiceProvider;
import 'package:hmm_console/core/data/vault/crypto/vault_crypto.dart';
import 'package:hmm_console/core/data/vault/vault_key_service.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:hmm_console/features/settings/presentation/widgets/secure_vault_section.dart';

/// Fixed-state fake for [VaultSessionController]. The provider type
/// parameter pins the notifier type to VaultSessionController itself, so
/// subclassing (not just implementing `Notifier<VaultStatus>`) is required
/// to override vaultSessionProvider in tests — same shape as the real
/// controller's own `now`-injection override in vault_session_test.dart,
/// just fixing `state` instead of wiring a fake clock. Every mutating method
/// is overridden so tests never touch vaultKeyServiceProvider / platform
/// channels; each call is recorded for assertions.
class _FakeVaultSessionController extends VaultSessionController {
  _FakeVaultSessionController(
    this._fixed, {
    this.biometricResult = true,
    this.passphraseResult = true,
  });

  final VaultStatus _fixed;
  final bool biometricResult;
  final bool passphraseResult;

  final List<String> calls = [];
  String? lastSetupPassphrase;
  String? lastUnlockPassphrase;

  @override
  VaultStatus build() => _fixed;

  /// Overridden so SecureVaultSection's initState-driven refresh() (the
  /// blocker fix) is a no-op here: this fake models a fixed status directly
  /// via [build], and the base refresh() would otherwise reach
  /// vaultKeyServiceProvider, which these tests never override.
  @override
  Future<void> refresh() async {
    calls.add('refresh');
  }

  @override
  Future<void> setup(String passphrase) async {
    calls.add('setup');
    lastSetupPassphrase = passphrase;
  }

  @override
  Future<bool> unlockWithBiometric() async {
    calls.add('unlockWithBiometric');
    return biometricResult;
  }

  @override
  Future<bool> unlockWithPassphrase(String passphrase) async {
    calls.add('unlockWithPassphrase');
    lastUnlockPassphrase = passphrase;
    return passphraseResult;
  }

  @override
  void lockNow() {
    calls.add('lockNow');
  }

  @override
  Future<void> reset() async {
    calls.add('reset');
  }
}

Widget _host(_FakeVaultSessionController controller) {
  return ProviderScope(
    overrides: [
      vaultSessionProvider.overrideWith(() => controller),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SecureVaultSection()),
    ),
  );
}

/// In-memory IVaultStore for the production-representative regression test
/// below — mirrors test/core/data/vault/vault_session_test.dart's
/// _FakeVaultStore. Empty store == no vault_meta.json == absent.
class _EmptyVaultStore implements IVaultStore {
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async {}
  @override
  Future<Uint8List> getBytes(String p) async =>
      throw VaultStoreException('missing', p);
  @override
  Future<bool> exists(String p) async => false;
  @override
  Future<void> delete(String p) async {}
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

void main() {
  testWidgets('absent shows Set up Secure Vault', (t) async {
    await t.pumpWidget(_host(_FakeVaultSessionController(VaultStatus.absent)));
    expect(find.text('Set up Secure Vault'), findsOneWidget);
    // Nothing to reset yet.
    expect(find.text('Reset Secure Vault'), findsNothing);
  });

  testWidgets('locked shows locked row + Unlock + Reset escape hatch',
      (t) async {
    await t.pumpWidget(_host(_FakeVaultSessionController(VaultStatus.locked)));
    expect(find.text('Secure Vault — locked'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.text('Reset Secure Vault'), findsOneWidget);
  });

  testWidgets('unlocked shows on row + Lock now + Reset escape hatch',
      (t) async {
    await t
        .pumpWidget(_host(_FakeVaultSessionController(VaultStatus.unlocked)));
    expect(find.text('Secure Vault — on'), findsOneWidget);
    expect(find.text('Lock now'), findsOneWidget);
    expect(find.text('Reset Secure Vault'), findsOneWidget);
  });

  testWidgets('corrupt shows warning row + Reset Secure Vault', (t) async {
    await t
        .pumpWidget(_host(_FakeVaultSessionController(VaultStatus.corrupt)));
    expect(find.text('Secure Vault — needs reset'), findsOneWidget);
    expect(find.text('Reset Secure Vault'), findsOneWidget);
  });

  testWidgets('unlocked → Lock now calls lockNow()', (t) async {
    final controller = _FakeVaultSessionController(VaultStatus.unlocked);
    await t.pumpWidget(_host(controller));
    await t.tap(find.text('Lock now'));
    await t.pumpAndSettle();
    expect(controller.calls, contains('lockNow'));
  });

  testWidgets(
      'locked → Unlock taps unlockWithBiometric(); success does not prompt '
      'for a passphrase', (t) async {
    final controller = _FakeVaultSessionController(VaultStatus.locked,
        biometricResult: true);
    await t.pumpWidget(_host(controller));
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();
    expect(controller.calls, contains('unlockWithBiometric'));
    expect(find.text('Unlock Secure Vault'), findsNothing);
  });

  testWidgets(
      'locked → Unlock falls back to a passphrase dialog when biometric '
      'fails', (t) async {
    final controller = _FakeVaultSessionController(VaultStatus.locked,
        biometricResult: false);
    await t.pumpWidget(_host(controller));
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();
    expect(controller.calls, contains('unlockWithBiometric'));
    expect(find.text('Unlock Secure Vault'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'hunter2');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await t.pumpAndSettle();

    expect(controller.calls, contains('unlockWithPassphrase'));
    expect(controller.lastUnlockPassphrase, 'hunter2');
  });

  testWidgets(
      'locked → wrong passphrase shows an inline error instead of unlocking',
      (t) async {
    final controller = _FakeVaultSessionController(VaultStatus.locked,
        biometricResult: false, passphraseResult: false);
    await t.pumpWidget(_host(controller));
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'wrong-guess');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await t.pumpAndSettle();

    expect(controller.calls, contains('unlockWithPassphrase'));
    expect(find.text('Incorrect passphrase.'), findsOneWidget);
  });

  testWidgets('absent → setup dialog shows the recovery warning', (t) async {
    final controller = _FakeVaultSessionController(VaultStatus.absent);
    await t.pumpWidget(_host(controller));
    await t.tap(find.text('Set up Secure Vault'));
    await t.pumpAndSettle();

    expect(
      find.text(
          'If you forget this passphrase, these files cannot be recovered.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'absent → setup dialog only submits when passphrase + confirm match '
      'and are non-empty', (t) async {
    final controller = _FakeVaultSessionController(VaultStatus.absent);
    await t.pumpWidget(_host(controller));
    await t.tap(find.text('Set up Secure Vault'));
    await t.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    final setUpButton =
        find.widgetWithText(FilledButton, 'Set Up');
    expect(t.widget<FilledButton>(setUpButton).onPressed, isNull);

    await t.enterText(fields.at(0), 'hunter2');
    await t.pumpAndSettle();
    // Mismatched confirm: still disabled.
    await t.enterText(fields.at(1), 'hunter3');
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(setUpButton).onPressed, isNull);

    // Matching confirm: enabled.
    await t.enterText(fields.at(1), 'hunter2');
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(setUpButton).onPressed, isNotNull);

    await t.tap(setUpButton);
    await t.pumpAndSettle();

    expect(controller.calls, contains('setup'));
    expect(controller.lastSetupPassphrase, 'hunter2');
  });

  testWidgets('reset dialog keeps the destructive button disabled until '
      'RESET is typed exactly', (t) async {
    final controller = _FakeVaultSessionController(VaultStatus.unlocked);
    await t.pumpWidget(_host(controller));
    await t.tap(find.text('Reset Secure Vault'));
    await t.pumpAndSettle();

    final resetButton =
        find.widgetWithText(FilledButton, 'Reset Secure Vault');
    expect(t.widget<FilledButton>(resetButton).onPressed, isNull);

    await t.enterText(find.byType(TextField), 'reset');
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(resetButton).onPressed, isNull);

    await t.enterText(find.byType(TextField), 'RESET');
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(resetButton).onPressed, isNotNull);

    await t.tap(resetButton);
    await t.pumpAndSettle();

    expect(controller.calls, contains('reset'));
  });

  testWidgets('corrupt → Reset Secure Vault opens the same destructive dialog',
      (t) async {
    final controller = _FakeVaultSessionController(VaultStatus.corrupt);
    await t.pumpWidget(_host(controller));
    await t.tap(find.text('Reset Secure Vault'));
    await t.pumpAndSettle();

    final resetButton =
        find.widgetWithText(FilledButton, 'Reset Secure Vault');
    expect(resetButton, findsOneWidget);
    expect(t.widget<FilledButton>(resetButton).onPressed, isNull);
  });

  group('blocker regression: production status initialization', () {
    // VaultSessionController.build() cannot await, so it returns
    // VaultStatus.locked until something calls refresh(). Before the fix,
    // nothing in lib/ ever called refresh(), so a device with no vault yet
    // stayed stuck on the `locked` row (Unlock/Reset) instead of showing
    // the `absent` "Set up Secure Vault" tile — the ONLY setup entry
    // point. This group drives the REAL VaultSessionController (not the
    // fixed-state fake above) through production-representative wiring —
    // only vaultKeyServiceProvider is overridden, exactly as
    // test/core/data/vault/vault_session_test.dart does — to prove
    // SecureVaultSection's initState now calls refresh() and renders the
    // real (absent) status.

    test('refresh() on an empty store yields VaultStatus.absent', () async {
      final svc = VaultKeyService(
          store: _EmptyVaultStore(), params: Argon2Params.test);
      final container = ProviderContainer(overrides: [
        vaultKeyServiceProvider.overrideWith((ref) async => svc),
      ]);
      addTearDown(container.dispose);
      final ctrl = container.read(vaultSessionProvider.notifier);

      // RED (pre-fix) would show here: with no caller of refresh() anywhere
      // in lib/, `container.read(vaultSessionProvider)` would still read
      // VaultStatus.locked at this point, never absent.
      expect(container.read(vaultSessionProvider), VaultStatus.locked);
      await ctrl.refresh();
      expect(container.read(vaultSessionProvider), VaultStatus.absent);
    });

    testWidgets(
        'SecureVaultSection renders "Set up Secure Vault" for a fresh '
        '(no-vault-yet) device, via initState-driven refresh() — not the '
        'stuck-locked default', (t) async {
      final svc = VaultKeyService(
          store: _EmptyVaultStore(), params: Argon2Params.test);
      await t.pumpWidget(ProviderScope(
        overrides: [
          vaultKeyServiceProvider.overrideWith((ref) async => svc),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SecureVaultSection()),
        ),
      ));
      // Let initState's refresh() (and the widget rebuild it triggers)
      // fully resolve. Pre-fix, nothing ever calls refresh(), so status
      // stays permanently at build()'s `locked` default and this would
      // never converge on the absent tile.
      await t.pumpAndSettle();

      expect(find.text('Set up Secure Vault'), findsOneWidget);
      expect(find.text('Secure Vault — locked'), findsNothing);
    });
  });
}
