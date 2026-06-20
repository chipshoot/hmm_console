import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/note_location.dart';

void main() {
  test('empty is empty; populated is not', () {
    expect(NoteLocation.empty.isEmpty, isTrue);
    expect(const NoteLocation(latitude: 1, longitude: 2).isEmpty, isFalse);
  });

  test('label is optional', () {
    const loc = NoteLocation(latitude: 1, longitude: 2);
    expect(loc.label, isNull);
    expect(loc.isEmpty, isFalse);
  });
}
