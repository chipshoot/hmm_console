import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_destination.dart';
import 'package:hmm_console/features/launcher/domain/launcher_matcher.dart';

const _reg = [
  LauncherDestination(
      id: 'gasLog', title: 'Gas Log', synonyms: ['fuel'], icon: Icons.abc, routeName: 'gasLogList'),
  LauncherDestination(
      id: 'serviceRecords', title: 'Service Log', synonyms: ['maintenance'], icon: Icons.abc, routeName: 'serviceRecords'),
  LauncherDestination(
      id: 'settings', title: 'Settings', synonyms: [], icon: Icons.abc, routeName: 'settings'),
];

List<String> _ids(String q, {Map<String, String> aliases = const {}}) =>
    match(q, registry: _reg, aliases: aliases).map((d) => d.id).toList();

void main() {
  test('empty / slash-only query returns nothing', () {
    expect(_ids(''), isEmpty);
    expect(_ids('/'), isEmpty);
    expect(_ids('   '), isEmpty);
  });

  test('prefix matches, alpha-sorted within a rank', () {
    // 'se' is a prefix of both "Service Log" and "Settings" (rank 3);
    // tie broken alphabetically by title.
    expect(_ids('se'), ['serviceRecords', 'settings']);
  });

  test('synonym matches', () {
    expect(_ids('fuel'), ['gasLog']);
    expect(_ids('maintenance'), ['serviceRecords']);
  });

  test('leading slash is stripped before matching', () {
    expect(_ids('/fuel'), ['gasLog']);
  });

  test('subsequence fuzzy match on title', () {
    expect(_ids('slog').contains('serviceRecords'), isTrue); // S-(ervice )-L-o-g
  });

  test('exact alias ranks above everything', () {
    // alias 'st' -> settings; 'st' is also a subsequence of "Settings".
    expect(_ids('st', aliases: {'st': 'settings'}).first, 'settings');
  });
}
