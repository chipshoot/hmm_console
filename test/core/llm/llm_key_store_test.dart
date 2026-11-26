import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/llm_key_store.dart';

class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage();
  final map = <String, String>{};
  @override
  Future<String?> read({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => map[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => map.remove(key);
  @override
  Future<Map<String, String>> readAll({
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => Map.of(map);
}

void main() {
  late _FakeStorage s;
  late LlmKeyStore store;
  setUp(() {
    s = _FakeStorage();
    store = LlmKeyStore(s);
  });

  test('key store trims pasted key', () async {
    await store.writeKey('a', '  sk-abc\n');
    expect(await store.readKey('a'), 'sk-abc');
    expect(s.map['llm.key.a'], 'sk-abc');
    expect(await store.hasKey('a'), isTrue);
  });

  test('blank key deletes', () async {
    await store.writeKey('a', 'sk');
    await store.writeKey('a', '   ');
    expect(await store.readKey('a'), isNull);
    expect(await store.hasKey('a'), isFalse);
  });

  test('consent set and checked', () async {
    expect(await store.hasConsent('a'), isFalse);
    await store.setConsent('a');
    expect(await store.hasConsent('a'), isTrue);
  });

  test('sweeps orphan keys', () async {
    for (final id in ['a', 'b']) {
      await store.writeKey(id, 'k');
      await store.setConsent(id);
    }
    s.map['hmm_access_token'] = 'tok';
    await store.sweepOrphans({'a'});
    expect(s.map.keys.toSet(), {
      'llm.key.a',
      'llm.consent.a',
      'hmm_access_token',
    });
  });
}
