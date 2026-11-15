import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/format_bytes.dart';

void main() {
  const mib = 1024 * 1024;
  const gib = 1024 * mib;

  test('below 1 GB shows whole MB', () {
    expect(formatVideoSize(742 * mib), '742 MB');
    expect(formatVideoSize(0), '0 MB');
  });

  test('1 GB and up shows one decimal', () {
    expect(formatVideoSize((1.3 * gib).round()), '1.3 GB');
  });

  test('a whole number of GB drops the .0', () {
    expect(formatVideoSize(2 * gib), '2 GB');
    expect(formatVideoSize(gib), '1 GB');
  });
}
