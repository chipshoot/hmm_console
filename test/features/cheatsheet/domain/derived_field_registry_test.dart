import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/derived_field_registry.dart';

String? _upper(Map<String, dynamic> e) => (e['name'] as String?)?.toUpperCase();
String? _boom(Map<String, dynamic> e) => throw StateError('bad ${e['name']}');

void main() {
  test('resolves a registered root + path, null otherwise', () {
    const r = DerivedFieldRegistry({
      'Thing': {'name': _upper},
    });
    expect(r.resolve('Thing', 'name', {'name': 'abc'}), 'ABC');
    expect(r.resolve('Thing', 'other', {'name': 'abc'}), isNull);
    expect(r.resolve('Other', 'name', {'name': 'abc'}), isNull);
    expect(const DerivedFieldRegistry().resolve('Thing', 'name', {}), isNull);
  });

  test('a throwing resolver yields null and logs the type only', () {
    final logs = <String>[];
    final old = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
    addTearDown(() => debugPrint = old);
    const r = DerivedFieldRegistry({
      'Thing': {'name': _boom},
    });
    expect(r.resolve('Thing', 'name', {'name': 'secret'}), isNull);
    expect(logs.join(), contains('StateError'));
    expect(logs.join(), isNot(contains('secret')));
  });
}
