import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pins the real dependency: a version bump that breaks a polyphonic surname
/// fails CI here instead of quietly mis-sorting the address book.
void main() {
  final t = ProviderContainer().read(pinyinTranscriberProvider);

  const surnames = {
    '曾': 'zeng',
    '单': 'shan',
    '解': 'xie',
    '区': 'ou',
    '仇': 'qiu',
    '朴': 'piao',
    '查': 'zha',
    '盖': 'ge',
  };
  for (final e in surnames.entries) {
    test('surname ${e.key} -> ${e.value}', () {
      expect(t.family(e.key), [e.value]);
    });
  }

  test('a compound surname and a given name', () {
    expect(t.family('欧阳'), ['ou', 'yang']);
    expect(t.given('伟'), ['wei']);
    expect(t.given('娜娜'), ['na', 'na']);
  });

  test('non-Han text passes through unchanged; empty is empty', () {
    expect(t.family('张 David'), ['zhang', 'David']);
    expect(t.given('Wei'), ['Wei']);
    expect(t.family(''), isEmpty);
    expect(t.given('   '), isEmpty);
  });

  test('output is toneless lowercase', () {
    for (final s in [...t.family('张'), ...t.given('伟明')]) {
      expect(s, s.toLowerCase());
      expect(s, isNot(matches(RegExp('[āáǎàēéěèīíǐìōóǒòūúǔù]'))));
    }
  });
}
