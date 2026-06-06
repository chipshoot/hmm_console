import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/rendering/generic_json_renderer.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

HmmNote _note({String? content, String? description}) => HmmNote(
      id: 1,
      uuid: 'u',
      subject: 's',
      authorId: 1,
      createDate: DateTime(2026, 1, 1),
      content: content,
      description: description,
    );

void main() {
  const r = GenericJsonRenderer();

  test('renders JSON object as a bold bullet tree', () {
    final out = r.render(_note(content: '{"Station":"Shell","Volume":45.2}'));
    expect(out, contains('- **Station:** Shell'));
    expect(out, contains('- **Volume:** 45.2'));
  });

  test('passes non-JSON content through verbatim', () {
    final out = r.render(_note(content: 'just text'));
    expect(out, 'just text');
  });

  test('empty content falls back to description then to a marker', () {
    expect(r.render(_note(description: 'desc')), 'desc');
    expect(r.render(_note()), '_(empty note)_');
  });
}
