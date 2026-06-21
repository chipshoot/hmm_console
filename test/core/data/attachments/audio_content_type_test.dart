import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';

const _audio = VaultRef(
    path: 'attachments/n/rec.m4a', contentType: 'audio/mp4', byteSize: 1024);

void main() {
  test('an audio/mp4 ref round-trips through the codec', () {
    final value = NoteAttachments(files: const [_audio]);
    final back = NoteAttachmentsCodec.decode(NoteAttachmentsCodec.encode(value));
    expect(back.files.single, _audio);
  });
}
