import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_flag.dart';

void main() {
  test('stored ints map to the seven colours in spec order', () {
    expect(NoteFlagColor.values.map((c) => c.stored), [0, 1, 2, 3, 4, 5, 6]);
    expect(NoteFlagColor.fromStored(0), NoteFlagColor.red);
    expect(NoteFlagColor.fromStored(4), NoteFlagColor.blue);
    expect(NoteFlagColor.fromStored(6), NoteFlagColor.grey);
  });

  test('null is unflagged; unknown values show as grey', () {
    expect(NoteFlagColor.fromStored(null), isNull);
    expect(NoteFlagColor.fromStored(42), NoteFlagColor.grey);
    expect(NoteFlagColor.fromStored(-1), NoteFlagColor.grey);
  });
}
