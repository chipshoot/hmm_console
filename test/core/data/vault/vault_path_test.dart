// Tests mirror the verbatim test-vector tables in
// docs/attachments-path-spec.md (Hmm repo). Adding a vector here
// without updating the spec is a process error; updating the spec
// without updating both sides' tests is worse.

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/vault_path.dart';

void main() {
  group('vaultRelativePathValidate — valid paths', () {
    const validInputs = <String>[
      'attachments/note-1/a.jpg',
      'attachments/note-42/9c8a3f12-7d6e-4a8b-90d1-2b4e5a6f7c01.jpg',
      'a',
      'a/b/c',
      'note-9999/photo-01.heic',
      '_.png',
      '-.webp',
      'a.b.c.jpg',
    ];

    for (final input in validInputs) {
      test('"$input" passes and is returned unchanged', () {
        expect(vaultRelativePathValidate(input), equals(input));
      });
    }
  });

  group('vaultRelativePathValidate — invalid paths', () {
    final invalidCases = <String, String>{
      '': 'empty path',
      '/foo': 'leading slash',
      'foo/': 'trailing empty segment',
      'foo//bar': 'empty segment',
      '..': 'parent segment',
      'foo/../bar': 'parent segment',
      './foo': 'dot segment',
      'foo/./bar': 'dot segment',
      r'foo\bar': 'backslash',
      'foo bar': 'space',
      ' foo': 'leading space',
      'foo ': 'trailing space',
      'foobar': 'control char',
      'héllo': 'non-ASCII',
      'foo.': 'trailing dot on segment',
      'CON': 'reserved Windows name',
      'attachments/CON/x.jpg': 'reserved Windows name as a segment',
      'prn': 'reserved Windows name (case-insensitive)',
    };

    invalidCases.forEach((input, reason) {
      test('rejects "$input" — $reason', () {
        expect(
          () => vaultRelativePathValidate(input),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    test('rejects segment over 255 chars', () {
      final longSegment = 'a' * 256;
      expect(
        () => vaultRelativePathValidate(longSegment),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts segment exactly 255 chars', () {
      final justFitting = 'a' * 255;
      expect(vaultRelativePathValidate(justFitting), equals(justFitting));
    });

    test('rejects path over 1024 chars', () {
      // Build segments of 100 chars each separated by '/' until > 1024.
      final seg = 'a' * 100;
      final parts = List<String>.filled(11, seg); // 11*100 + 10 = 1110
      final tooLong = parts.join('/');
      expect(tooLong.length, greaterThan(1024));
      expect(
        () => vaultRelativePathValidate(tooLong),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts path exactly 1024 chars', () {
      // 9 segments of 100 chars joined with 8 '/' = 908; then one more
      // '/' (909) + a final segment of 115 chars = 1024.
      final parts = List<String>.filled(9, 'a' * 100);
      final assembled = '${parts.join('/')}/${'a' * 115}';
      expect(assembled.length, equals(1024));
      expect(vaultRelativePathValidate(assembled), equals(assembled));
    });
  });

  group('vaultRelativePathJoin', () {
    test('joins valid segments with /', () {
      expect(
        vaultRelativePathJoin(['attachments', 'note-5', 'x.jpg']),
        equals('attachments/note-5/x.jpg'),
      );
    });

    test('throws when a segment contains a separator', () {
      expect(
        () => vaultRelativePathJoin(['a', 'b/c']),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => vaultRelativePathJoin(['a', r'b\c']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on empty segment', () {
      expect(
        () => vaultRelativePathJoin(['a', '']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on empty input', () {
      expect(
        () => vaultRelativePathJoin(<String>[]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on .. segment', () {
      expect(
        () => vaultRelativePathJoin(['a', '..', 'b']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on reserved Windows name segment', () {
      expect(
        () => vaultRelativePathJoin(['attachments', 'CON', 'x.jpg']),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
