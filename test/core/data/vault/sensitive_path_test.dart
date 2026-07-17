import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/sensitive_path.dart';

void main() {
  group('isSensitiveVaultPath', () {
    test('true when a segment is "sensitive"', () {
      expect(isSensitiveVaultPath('attachments/note-1/sensitive/a.jpg'), isTrue);
    });
    test('false for a normal attachment path', () {
      expect(isSensitiveVaultPath('attachments/note-1/a.jpg'), isFalse);
    });
    test('false when "sensitive" is only a substring of a segment', () {
      expect(isSensitiveVaultPath('attachments/note-1/sensitiveish.jpg'), isFalse);
    });
    test('false for vault_meta.json', () {
      expect(isSensitiveVaultPath('vault_meta.json'), isFalse);
    });
  });

  group('buildSensitiveAttachmentPath', () {
    test('produces a validated sensitive path', () {
      final path = buildSensitiveAttachmentPath(noteId: 7, ext: 'jpg');
      expect(path, startsWith('attachments/note-7/sensitive/'));
      expect(path, endsWith('.jpg'));
      expect(isSensitiveVaultPath(path), isTrue);
    });
  });
}
