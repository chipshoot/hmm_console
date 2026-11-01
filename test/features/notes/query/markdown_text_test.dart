import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/search_normalize.dart';
import 'package:hmm_console/features/notes/query/markdown_text.dart';

void main() {
  test('strips markup, keeps link text, drops images and tables', () {
    const md =
        '# Trip\n**Bold** _it_ `code` [site](https://x.y)\n'
        '![p](hmm-attachment://attachments/a.jpg)\n\n| a | b |\n|---|---|\n| 1 | 2 |\n'
        '- [ ] milk\n- [x] eggs\n\n<div>raw</div>';
    final t = markdownToPlainText(md);
    expect(t, contains('Trip'));
    expect(t, contains('Bold it code site'));
    expect(t, contains('milk'));
    expect(t, contains('eggs'));
    for (final bad in [
      '**',
      '`',
      '](',
      '![',
      '[ ]',
      '[x]',
      '| a',
      'https://',
      '<div>',
      'raw',
    ]) {
      expect(t, isNot(contains(bad)), reason: bad);
    }
  });

  test('empty input', () => expect(markdownToPlainText(''), ''));

  test('foldForMatch keeps length', () {
    expect(foldForMatch('Crème BRÛLÉE'), 'creme brulee');
    expect(foldForMatch('Crème').length, 'Crème'.length);
    expect(foldForMatch('İ x').length, 'İ x'.length);
    expect(foldForMatch('a  b'), 'a  b');
  });
}
