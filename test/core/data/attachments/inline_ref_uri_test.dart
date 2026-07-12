import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/inline_ref_uri.dart';

void main() {
  test('format/parse real image uri round-trips the vault path', () {
    const path = 'attachments/note-123/Login.png';
    final uri = formatImageUri(path);
    expect(uri, 'hmm-attachment://attachments/note-123/Login.png');
    expect(parseImageUri(uri), path);
  });

  test('pending uri round-trips the uuid', () {
    final uri = formatPendingUri('abc-1');
    expect(uri, 'hmm-attachment://pending/abc-1');
    expect(pendingUuidOf(uri), 'abc-1');
    expect(parseImageUri(uri), isNull); // pending is not a real image path
  });

  test('non-attachment / malformed uris return null', () {
    expect(parseImageUri('https://example.com/x.png'), isNull);
    expect(parseImageUri('hmm-note://uuid-1'), isNull);
    expect(pendingUuidOf('hmm-attachment://attachments/note-1/x.png'), isNull);
  });

  test('imageRefPathsIn and pendingUuidsIn extract inline refs', () {
    const md = 'a\n\n![x](hmm-attachment://attachments/note-1/a.png)\n\n'
        'b ![y](hmm-attachment://pending/u9) c\n'
        '![z](https://ext/x.png)';
    expect(imageRefPathsIn(md), ['attachments/note-1/a.png']);
    expect(pendingUuidsIn(md), ['u9']);
  });

  test('rewritePendingToVault replaces pending uris with real image uris', () {
    const md = '![y](hmm-attachment://pending/u9) and text';
    final out = rewritePendingToVault(md, {'u9': 'attachments/note-5/y.png'});
    expect(out, '![y](hmm-attachment://attachments/note-5/y.png) and text');
    expect(pendingUuidsIn(out), isEmpty);
  });

  test('removePendingImage strips the failed placeholder markdown', () {
    const md = 'a ![y](hmm-attachment://pending/u9) b';
    final out = removePendingImage(md, 'u9');
    expect(out, 'a  b');
    expect(pendingUuidsIn(out), isEmpty);
  });

  test('a titled image url is captured without the title', () {
    const md = '![a](hmm-attachment://attachments/note-1/a.png "cap")';
    expect(imageRefPathsIn(md), ['attachments/note-1/a.png']);
  });

  test('format/parse note uri round-trips the uuid', () {
    expect(formatNoteUri('abc-1'), 'hmm-note://abc-1');
    expect(parseNoteUri('hmm-note://abc-1'), 'abc-1');
    expect(parseNoteUri('hmm-note://abc-1#block2'), 'abc-1'); // anchor ignored
    expect(parseNoteUri('hmm-attachment://x'), isNull);
    expect(parseNoteUri('https://x'), isNull);
  });

  test('noteUuidsIn extracts note-link uuids', () {
    const md = 'see [a](hmm-note://u1) and [b](https://x) and [c](hmm-note://u2)';
    expect(noteUuidsIn(md), ['u1', 'u2']);
  });
}
