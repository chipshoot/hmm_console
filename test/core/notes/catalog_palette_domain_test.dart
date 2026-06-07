import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';

void main() {
  group('domainKeyFor', () {
    test('FQN catalog -> middle segment', () {
      expect(CatalogPalette.domainKeyFor('Hmm.AutomobileMan.GasLog'),
          'AutomobileMan');
      expect(CatalogPalette.domainKeyFor('Hmm.AutomobileMan.GasStation'),
          'AutomobileMan');
    });
    test('single-segment catalog -> itself', () {
      expect(CatalogPalette.domainKeyFor('General'), 'General');
    });
    test('null -> Other', () {
      expect(CatalogPalette.domainKeyFor(null), 'Other');
    });
  });

  group('domainStyle', () {
    test('strips trailing "Man" and uses the domain color', () {
      final s = CatalogPalette.domainStyle('AutomobileMan');
      expect(s.displayName, 'Automobile');
      expect(s.color, const Color(0xFF0A84FF));
    });
    test('General keeps its name + color', () {
      final s = CatalogPalette.domainStyle('General');
      expect(s.displayName, 'General');
      expect(s.color, const Color(0xFF34C759));
    });
    test('unknown domain -> name as-is + default gray', () {
      final s = CatalogPalette.domainStyle('Other');
      expect(s.displayName, 'Other');
      expect(s.color, const Color(0xFF8E8E93));
    });
  });
}
