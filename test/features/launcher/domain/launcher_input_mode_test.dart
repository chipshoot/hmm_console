import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_input_mode.dart';

void main() {
  test('modeOf classifies input', () {
    expect(modeOf(''), LauncherInputMode.empty);
    expect(modeOf('   '), LauncherInputMode.empty);
    expect(modeOf('/'), LauncherInputMode.command);
    expect(modeOf('/gas'), LauncherInputMode.command);
    expect(modeOf('  /gas'), LauncherInputMode.command);
    expect(modeOf('gas'), LauncherInputMode.assistant);
  });

  test('commandQuery returns the text after the slash, trimmed', () {
    expect(commandQuery('/gas'), 'gas');
    expect(commandQuery('  /  gas log '), 'gas log');
    expect(commandQuery('/'), '');
    expect(commandQuery('gas'), ''); // not command mode
  });
}
