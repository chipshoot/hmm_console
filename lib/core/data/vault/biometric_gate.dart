// Thin, fakeable wrapper over local_auth so the vault session controller
// can be unit-tested headlessly without a real platform channel.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Gate in front of the platform biometric/passcode check. authenticate()
/// resolves true only on a successful check; any failure, cancellation, or
/// unavailability resolves false — it never throws.
abstract interface class BiometricGate {
  Future<bool> authenticate();
}

class LocalAuthBiometricGate implements BiometricGate {
  LocalAuthBiometricGate([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock your secure vault',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false; // unavailable / not enrolled / cancelled → not authenticated
    }
  }
}

final biometricGateProvider =
    Provider<BiometricGate>((ref) => LocalAuthBiometricGate());
