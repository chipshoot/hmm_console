import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/route_names.dart';

void main() {
  test('launcher route names exist', () {
    final names = RouterNames.values.map((r) => r.name).toSet();
    expect(names.contains('launcherSearch'), isTrue);
    expect(names.contains('launcherManage'), isTrue);
  });
}
