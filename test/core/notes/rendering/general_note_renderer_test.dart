import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/rendering/general_note_renderer.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

HmmNote _note({String? content, String? description}) => HmmNote(
      id: 1, uuid: 'u', subject: 's', authorId: 1,
      createDate: DateTime(2026, 1, 1),
      content: content, description: description,
    );

void main() {
  const r = GeneralNoteRenderer();

  test('returns markdown body verbatim', () {
    expect(r.render(_note(content: '# Hi\n\n- a')), '# Hi\n\n- a');
  });

  test('empty body falls back to description, then marker', () {
    expect(r.render(_note(description: 'd')), 'd');
    expect(r.render(_note()), '_(empty note)_');
  });
}
