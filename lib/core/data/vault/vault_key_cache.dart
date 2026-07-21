import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the derived vault key in the platform secure store so a biometric
/// unlock can restore it without re-deriving from the passphrase. The key is
/// never written anywhere else and never leaves the device.
abstract interface class VaultKeyCache {
  Future<Uint8List?> read();
  Future<void> write(Uint8List key);
  Future<void> clear();
}

class SecureStorageVaultKeyCache implements VaultKeyCache {
  SecureStorageVaultKeyCache([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _keyName = 'hmm_vault_key_b64';

  @override
  Future<Uint8List?> read() async {
    final v = await _storage.read(key: _keyName);
    if (v == null) return null;
    return base64Decode(v);
  }

  @override
  Future<void> write(Uint8List key) =>
      _storage.write(key: _keyName, value: base64Encode(key));

  @override
  Future<void> clear() => _storage.delete(key: _keyName);
}
