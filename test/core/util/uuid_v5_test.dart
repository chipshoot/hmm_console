import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/uuid.dart';

void main() {
  test('uuidV5 matches the RFC 4122 DNS vector', () {
    expect(
      uuidV5('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'www.example.com'),
      '2ed6657d-e927-568b-95e1-2665a8aea6a2',
    );
  });
}
