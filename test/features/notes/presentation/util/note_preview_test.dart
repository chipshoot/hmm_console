import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/util/note_preview.dart';

void main() {
  test('null and empty content yield empty string', () {
    expect(notePreview(null), '');
    expect(notePreview(''), '');
    expect(notePreview('   \n  \n'), '');
  });

  test('returns first non-blank line', () {
    expect(notePreview('\n\nHello world\nsecond'), 'Hello world');
  });

  test('strips common markdown markers', () {
    expect(notePreview('# Heading'), 'Heading');
    expect(notePreview('- bullet item'), 'bullet item');
    expect(notePreview('> quote'), 'quote');
    expect(notePreview('**bold** text'), 'bold text');
    expect(notePreview('`code` snippet'), 'code snippet');
  });

  test('JSON domain payload yields empty (not human text)', () {
    expect(notePreview('{"make":"Toyota","model":"Camry"}'), '');
    expect(notePreview('[1,2,3]'), '');
  });
}
