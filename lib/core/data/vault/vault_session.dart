// Session backbone for the sensitive-attachments vault (Phase 4b / Task B3).
//
// VaultSessionController is the single source of truth the UI reads for
// whether the vault is set up / locked / unlocked, and it owns the timed
// relock policy: the in-memory key drops (not the secure-storage cache —
// see VaultKeyService.lock()) when the app goes to the background or after
// 5 minutes of inactivity.
//
// Wiring note: vaultKeyServiceProvider is a FutureProvider<VaultKeyService>
// (it awaits the base vault store to resolve), so this controller cannot
// read it synchronously. It resolves + memoizes the service the first time
// any method needs it, then reuses that instance for the rest of the
// container's lifetime — consistent with how the rest of the app treats
// vaultKeyServiceProvider as a long-lived singleton per container.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/attachment_providers.dart' show vaultKeyServiceProvider;
import 'biometric_gate.dart';
import 'vault_key_service.dart';

/// UI-facing state of the sensitive vault.
enum VaultStatus { absent, locked, unlocked, corrupt }

const _inactivityTimeout = Duration(minutes: 5);

class VaultSessionController extends Notifier<VaultStatus> {
  VaultSessionController({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  VaultKeyService? _svc;
  DateTime _lastAccessAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  VaultStatus build() {
    // Cannot await here, so start out locked; the UI treats "locked" as
    // the safe default until the caller's first refresh() resolves the
    // real state (tests always await refresh()/setup() before asserting).
    final observer = _LifecycleObserver(onPaused: _onAppPaused);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(observer);
    });
    return VaultStatus.locked;
  }

  void _onAppPaused() {
    if (state == VaultStatus.unlocked) lockNow();
  }

  Future<VaultKeyService> _service() async {
    final cached = _svc;
    if (cached != null) return cached;
    final resolved = await ref.read(vaultKeyServiceProvider.future);
    return _svc = resolved;
  }

  void _touchNow() {
    _lastAccessAt = _now();
  }

  /// Re-reads vault_meta.json / current key state and refreshes [state].
  Future<void> refresh() async {
    final svc = await _service();
    final cfg = await svc.configState();
    state = switch (cfg) {
      VaultConfigState.absent => VaultStatus.absent,
      VaultConfigState.corrupt => VaultStatus.corrupt,
      VaultConfigState.configured =>
        svc.isUnlocked ? VaultStatus.unlocked : VaultStatus.locked,
    };
  }

  /// Attempts a biometric unlock, restoring the key from the secure-storage
  /// cache on success. Any throw from the cache/service (corrupt cached
  /// key, PlatformException, etc.) is treated as a clean unlock failure —
  /// stays locked, never propagates — so the UI can fall back to the
  /// passphrase prompt.
  Future<bool> unlockWithBiometric() async {
    final gate = ref.read(biometricGateProvider);
    if (!await gate.authenticate()) return false;
    final svc = await _service();
    bool restored;
    try {
      restored = await svc.unlockFromCache();
    } catch (_) {
      restored = false;
    }
    if (!restored) return false;
    _touchNow();
    state = VaultStatus.unlocked;
    return true;
  }

  Future<bool> unlockWithPassphrase(String passphrase) async {
    final svc = await _service();
    if (!await svc.unlock(passphrase)) return false;
    _touchNow();
    state = VaultStatus.unlocked;
    return true;
  }

  Future<void> setup(String passphrase) async {
    final svc = await _service();
    await svc.setupPassphrase(passphrase);
    _touchNow();
    state = VaultStatus.unlocked;
  }

  void lockNow() {
    _svc?.lock();
    state = VaultStatus.locked;
  }

  Future<void> reset() async {
    final svc = await _service();
    await svc.reset();
    state = VaultStatus.absent;
  }

  /// Called on user activity while the vault is unlocked. Relocks if more
  /// than [_inactivityTimeout] has elapsed since the last touch; otherwise
  /// bumps the last-access clock.
  void touch() {
    if (state != VaultStatus.unlocked) return;
    if (_now().difference(_lastAccessAt) > _inactivityTimeout) {
      lockNow();
    } else {
      _touchNow();
    }
  }
}

/// Minimal WidgetsBindingObserver so the Notifier (which isn't a State) can
/// react to app lifecycle transitions. Registered in build(), removed via
/// ref.onDispose.
class _LifecycleObserver with WidgetsBindingObserver {
  _LifecycleObserver({required this.onPaused});
  final VoidCallback onPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) onPaused();
  }
}

final vaultSessionProvider =
    NotifierProvider<VaultSessionController, VaultStatus>(
        VaultSessionController.new);
