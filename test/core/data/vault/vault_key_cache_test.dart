import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/vault_key_cache.dart';

class _MemCache implements VaultKeyCache {
  Uint8List? _v;
  @override
  Future<Uint8List?> read() async => _v;
  @override
  Future<void> write(Uint8List key) async => _v = key;
  @override
  Future<void> clear() async => _v = null;
}

void main() {
  test('in-memory cache round-trips and clears', () async {
    final c = _MemCache();
    expect(await c.read(), isNull);
    await c.write(Uint8List.fromList([1, 2, 3]));
    expect(await c.read(), Uint8List.fromList([1, 2, 3]));
    await c.clear();
    expect(await c.read(), isNull);
  });
}
