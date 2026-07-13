import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_markdown_body.dart';

void main() {
  test('dispatches a hmm-note link to onNote with the uuid', () {
    String? note; Uri? ext;
    dispatchMarkdownLink('hmm-note://u1',
        onNote: (u) => note = u, onExternal: (x) => ext = x);
    expect(note, 'u1');
    expect(ext, isNull);
  });

  test('dispatches an https link to onExternal', () {
    String? note; Uri? ext;
    dispatchMarkdownLink('https://example.com/v',
        onNote: (u) => note = u, onExternal: (x) => ext = x);
    expect(ext, Uri.parse('https://example.com/v'));
    expect(note, isNull);
  });

  test('dispatches a plain http link to onExternal', () {
    String? note; Uri? ext;
    dispatchMarkdownLink('http://example.com/v',
        onNote: (u) => note = u, onExternal: (x) => ext = x);
    expect(ext, Uri.parse('http://example.com/v'));
    expect(note, isNull);
  });

  test('ignores null / unknown-scheme links', () {
    var calls = 0;
    dispatchMarkdownLink(null,
        onNote: (_) => calls++, onExternal: (_) => calls++);
    dispatchMarkdownLink('mailto:x@y.z',
        onNote: (_) => calls++, onExternal: (_) => calls++);
    expect(calls, 0);
  });
}
