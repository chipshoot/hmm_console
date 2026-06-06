import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/rendering/gas_log_note_renderer.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

HmmNote _note(String? content) => HmmNote(
      id: 1, uuid: 'u', subject: 's', authorId: 1,
      createDate: DateTime(2026, 1, 1), content: content,
    );

void main() {
  const r = GasLogNoteRenderer();

  test('catalogName matches the domain catalog', () {
    expect(GasLogNoteRenderer.catalogName, 'Hmm.AutomobileMan.GasLog');
  });

  test('unwraps the GasLog envelope and renders its fields', () {
    final out = r.render(_note(
        '{"note":{"content":{"GasLog":{"station":"Shell","_v":1}}}}'));
    expect(out, contains('### Gas Log'));
    expect(out, contains('- **station:** Shell'));
  });

  test('falls back without throwing on malformed content', () {
    expect(() => r.render(_note('not json')), returnsNormally);
    expect(() => r.render(_note(null)), returnsNormally);
  });
}
