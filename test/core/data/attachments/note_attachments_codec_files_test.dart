import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';

const _pdf = VaultRef(
    path: 'attachments/n/r.pdf', contentType: 'application/pdf', byteSize: 3);
const _img = VaultRef(
    path: 'attachments/n/a.jpg', contentType: 'image/jpeg', byteSize: 9);

void main() {
  test('files round-trip through encode/decode', () {
    final value = NoteAttachments(files: const [_pdf]);
    final encoded = NoteAttachmentsCodec.encode(value);
    final back = NoteAttachmentsCodec.decode(encoded);
    expect(back.files, [_pdf]);
  });

  test('images-only payload encodes identically to before (no files key)', () {
    final value = NoteAttachments(images: const [_img]);
    final encoded = NoteAttachmentsCodec.encode(value)!;
    expect(encoded.contains('files'), isFalse);
  });
}
