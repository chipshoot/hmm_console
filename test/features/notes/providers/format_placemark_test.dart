import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hmm_console/features/notes/providers/note_location_capture.dart';

void main() {
  test('joins locality + admin area, skipping blanks', () {
    final p = Placemark(locality: 'Seattle', administrativeArea: 'WA');
    expect(formatPlacemark(p), 'Seattle, WA');
  });

  test('returns null for a null placemark or all-blank fields', () {
    expect(formatPlacemark(null), isNull);
    expect(formatPlacemark(Placemark(locality: '', administrativeArea: '')),
        isNull);
  });
}
