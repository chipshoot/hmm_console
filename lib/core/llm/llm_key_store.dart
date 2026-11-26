import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Per-device API keys and "send to this provider" consent, in the platform
/// secure store. Never synced, never logged.
class LlmKeyStore {
  LlmKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyPrefix = 'llm.key.';
  static const _consentPrefix = 'llm.consent.';

  Future<String?> readKey(String id) => _storage.read(key: '$_keyPrefix$id');

  Future<void> writeKey(String id, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return deleteKey(id);
    await _storage.write(key: '$_keyPrefix$id', value: trimmed);
  }

  Future<void> deleteKey(String id) => _storage.delete(key: '$_keyPrefix$id');

  Future<bool> hasKey(String id) async {
    final k = await readKey(id);
    return k != null && k.isNotEmpty;
  }

  Future<bool> hasConsent(String id) async =>
      await _storage.read(key: '$_consentPrefix$id') != null;

  Future<void> setConsent(String id) =>
      _storage.write(key: '$_consentPrefix$id', value: '1');

  Future<void> deleteConsent(String id) =>
      _storage.delete(key: '$_consentPrefix$id');

  /// Deletes `llm.key.*` / `llm.consent.*` entries whose engine id is not in
  /// [liveIds]. Other entries (the Hmm login tokens) are never touched.
  Future<void> sweepOrphans(Set<String> liveIds) async {
    final all = await _storage.readAll();
    for (final k in all.keys) {
      for (final prefix in const [_keyPrefix, _consentPrefix]) {
        if (k.startsWith(prefix) &&
            !liveIds.contains(k.substring(prefix.length))) {
          await _storage.delete(key: k);
        }
      }
    }
  }
}

final llmKeyStoreProvider = Provider<LlmKeyStore>((ref) => LlmKeyStore());
