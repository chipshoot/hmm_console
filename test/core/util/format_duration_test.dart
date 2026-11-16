import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/format_duration.dart';

void main() {
  test('formatClock shows m:ss, and h:mm:ss from an hour', () {
    expect(formatClock(0), '0:00');
    expect(formatClock(48), '0:48');
    expect(formatClock(605), '10:05');
    expect(formatClock(3725), '1:02:05');
  });

  test('formatVideoLength rounds milliseconds down to whole seconds', () {
    expect(formatVideoLength(48999), '0:48');
    expect(formatVideoLength(61000), '1:01');
  });
}
