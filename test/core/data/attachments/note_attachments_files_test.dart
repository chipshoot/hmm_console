import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';

const _pdf = VaultRef(
    path: 'attachments/n/r.pdf', contentType: 'application/pdf', byteSize: 3);

void main() {
  test('files participate in isEmpty and equality', () {
    final a = NoteAttachments(files: const [_pdf]);
    expect(a.isEmpty, isFalse);
    expect(a, NoteAttachments(files: const [_pdf]));
    expect(a == NoteAttachments.empty, isFalse);
  });

  test('empty payload still empty', () {
    expect(NoteAttachments.empty.isEmpty, isTrue);
  });
}
