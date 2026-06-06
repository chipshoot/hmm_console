import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';

void main() {
  test('General name constant is "General"', () {
    expect(kGeneralCatalogName, 'General');
  });

  test('known catalog returns friendly name + color', () {
    final s = CatalogPalette.styleFor('Hmm.AutomobileMan.GasLog');
    expect(s.displayName, 'Gas Log');
    expect(s.color, const Color(0xFFFFD60A));
  });

  test('unknown FQN derives last segment + default gray', () {
    final s = CatalogPalette.styleFor('Hmm.Foo.WidgetThing');
    expect(s.displayName, 'WidgetThing');
    expect(s.color, const Color(0xFF8E8E93));
  });

  test('null catalog returns a default style', () {
    final s = CatalogPalette.styleFor(null);
    expect(s.color, const Color(0xFF8E8E93));
  });
}
