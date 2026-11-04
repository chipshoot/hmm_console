import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/states/notes_multi_select.dart';

void main() {
  ProviderContainer make() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('starts inactive and empty', () {
    final s = make().read(notesMultiSelectProvider);
    expect(s.active, isFalse);
    expect(s.ids, isEmpty);
  });

  test('enter(5) is active with {5}', () {
    final c = make();
    c.read(notesMultiSelectProvider.notifier).enter(5);
    final s = c.read(notesMultiSelectProvider);
    expect(s.active, isTrue);
    expect(s.ids, {5});
  });

  test('enter() with no id is active and empty', () {
    final c = make();
    c.read(notesMultiSelectProvider.notifier).enter();
    final s = c.read(notesMultiSelectProvider);
    expect(s.active, isTrue);
    expect(s.ids, isEmpty);
  });

  test('toggle adds and removes', () {
    final c = make();
    final n = c.read(notesMultiSelectProvider.notifier)..enter(1);
    n.toggle(2);
    expect(c.read(notesMultiSelectProvider).ids, {1, 2});
    n.toggle(1);
    expect(c.read(notesMultiSelectProvider).ids, {2});
  });

  test('selectAll unions', () {
    final c = make();
    final n = c.read(notesMultiSelectProvider.notifier)..enter(1);
    n.selectAll([2, 3]);
    expect(c.read(notesMultiSelectProvider).ids, {1, 2, 3});
  });

  test('keepOnly intersects', () {
    final c = make();
    final n = c.read(notesMultiSelectProvider.notifier)..enter(1);
    n.selectAll([2, 3]);
    n.keepOnly([2, 3, 4]);
    expect(c.read(notesMultiSelectProvider).ids, {2, 3});
  });

  test('exit clears and deactivates', () {
    final c = make();
    final n = c.read(notesMultiSelectProvider.notifier)..enter(1);
    n.exit();
    final s = c.read(notesMultiSelectProvider);
    expect(s.active, isFalse);
    expect(s.ids, isEmpty);
  });
}
