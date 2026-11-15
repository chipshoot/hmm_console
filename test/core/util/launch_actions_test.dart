import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/launch_actions.dart';

void main() {
  _phoneCodeTests();
  group('telUri', () {
    test('strips punctuation and spacing', () {
      expect(telUri('(555) 123-4567').toString(), 'tel:5551234567');
    });

    test('keeps a leading + for international numbers', () {
      expect(telUri('+1 555-123-4567').toString(), 'tel:+15551234567');
    });

    test('a + anywhere else is not punctuation worth keeping', () {
      expect(telUri('555-123-4567 1+2').toString(), 'tel:555123456712');
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

    // Apple Maps search can't find Chinese street addresses and reads "中国"
    // as Japan's Chūgoku region (Shanghai landed in Okayama, 2026-11-15).
    test('a Chinese address opens Google Maps with the address as typed', () {
      const address = '中国 上海市 浦东新区 世纪大道100号 邮编 200120';
      final uri = mapsUri(address);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], address);
    });

    test('Chinese characters anywhere send it to Google Maps', () {
      expect(mapsUri('Room 5, 世纪大道100号, Shanghai').host, 'www.google.com');
    });

    test('an address with no Chinese characters stays on Apple Maps', () {
      expect(
        mapsUri('100 Century Ave, Shanghai, China').host,
        'maps.apple.com',
      );
      expect(mapsUri('12 Rue de Rivoli, Paris').host, 'maps.apple.com');
    });
  });
}

void _phoneCodeTests() {
  test('digits after an extension marker are not dialled', () {
    expect(telUri('555 0100 x23').toString(), 'tel:5550100');
    expect(telUri('+1 555 0100 ext 5').toString(), 'tel:+15550100');
    expect(telUri('555 0100,,2').toString(), 'tel:5550100');
    expect(telUri('555 0100;2').toString(), 'tel:5550100');
    expect(telUri('555 0100 #9').toString(), 'tel:5550100');
    expect(telUri('555 0100 X23').toString(), 'tel:5550100');
  });

  test('a code-prefixed stored phone dials as an international number', () {
    expect(telUri('+86 138 0013 8000').toString(), 'tel:+8613800138000');
  });
}
