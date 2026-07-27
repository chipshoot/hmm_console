import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/launch_actions.dart';

void main() {
  group('telUri', () {
    test('strips punctuation and spacing', () {
      expect(telUri('(555) 123-4567').toString(), 'tel:5551234567');
    });

    test('keeps a leading + for international numbers', () {
      expect(telUri('+1 555-123-4567').toString(), 'tel:+15551234567');
    });

    test('a + anywhere else is not punctuation worth keeping', () {
      expect(telUri('555-123-4567 ext+2').toString(), 'tel:55512345672');
    });

    test('an already-clean number is unchanged', () {
      expect(telUri('5551234567').toString(), 'tel:5551234567');
    });
  });

  group('mapsUri', () {
    test('percent-encodes the query', () {
      expect(
        mapsUri('1 Main St').toString(),
        contains('maps.apple.com/?q=1%20Main%20St'),
      );
    });

    test('encodes characters that would break the query', () {
      final uri = mapsUri('12 O&M Rd, Apt #3');
      expect(uri.toString(), contains('%26')); // &
      expect(uri.toString(), contains('%23')); // #
    });

    test('is https so it resolves on platforms without Apple Maps', () {
      expect(mapsUri('1 Main St').scheme, 'https');
    });
  });
}
