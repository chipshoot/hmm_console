import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/note_sharer.dart';

HmmNote _note({String subject = 'Trip', String? body}) => HmmNote(
  id: 1,
  uuid: 'u1',
  subject: subject,
  content: body,
  authorId: 1,
  createDate: DateTime(2026),
);

void main() {
  test('subject and body are joined by a blank line', () {
    expect(shareTextFor(_note(body: '**Day 1**')), 'Trip\n\n**Day 1**');
  });

  test('an empty or null body shares the subject alone', () {
    expect(shareTextFor(_note(body: '')), 'Trip');
    expect(shareTextFor(_note()), 'Trip');
  });
}
