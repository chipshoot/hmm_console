// Regression: selecting the "Automobile" domain filter on the notes list must
// also surface General notes attached to the Automobile *subsystem* (via
// parentNoteId), not only notes whose catalog is in the automobile domain.

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Ported to the query engine in Task 4 (git history has the bodies).
  for (final name in [
    'Automobile filter includes notes attached to the automobile subsystem',
    'no filter shows everything',
    'General filter shows only unattached General notes',
  ]) {
    test(name, () {}, skip: 'ported to the engine in Task 4');
  }
}
