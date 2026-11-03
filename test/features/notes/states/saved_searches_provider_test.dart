import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/settings/providers/settings_bus_provider.dart';
import 'package:hmm_console/features/notes/states/saved_searches_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _make() async {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer();
  addTearDown(c.dispose);
  c.listen(savedSearchesProvider, (_, _) {});
  return c;
}

Future<List<String>> _names(ProviderContainer c) async {
  // Fresh container re-reads prefs: proves persistence, not just state.
  final c2 = ProviderContainer();
  addTearDown(c2.dispose);
  c2.listen(savedSearchesProvider, (_, _) {});
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return [
    for (final s in c2.read(savedSearchesProvider)) '${s.order}:${s.name}',
  ];
}

Future<String?> _stamp() async =>
    (await SharedPreferences.getInstance()).getString('settings.last_modified');

void main() {
  test('add appends, persists, renumbers and bumps the stamp', () async {
    final c = await _make();
    final n = c.read(savedSearchesProvider.notifier);
    final a = await n.add('A', const NoteQuery.initial());
    await n.add('B', const NoteQuery.initial());
    expect(a.id, isNotEmpty);
    expect(await _names(c), ['0:A', '1:B']);
    expect(await _stamp(), isNotNull);
  });

  test('rename, move up, move down, remove, restore', () async {
    final c = await _make();
    final n = c.read(savedSearchesProvider.notifier);
    final a = await n.add('A', const NoteQuery.initial());
    final b = await n.add('B', const NoteQuery.initial());
    await n.add('C', const NoteQuery.initial());

    await n.rename(a.id, 'A2');
    expect(await _names(c), ['0:A2', '1:B', '2:C']);

    await n.move(b.id, -1);
    expect(await _names(c), ['0:B', '1:A2', '2:C']);

    await n.move(b.id, 1);
    expect(await _names(c), ['0:A2', '1:B', '2:C']);

    await n.remove(a.id);
    expect(await _names(c), ['0:B', '1:C']);

    await n.restore(a.copyWith(name: 'A2', order: 0));
    expect(await _names(c), ['0:A2', '1:B', '2:C']);
  });

  test('move clamps at the ends', () async {
    final c = await _make();
    final n = c.read(savedSearchesProvider.notifier);
    final a = await n.add('A', const NoteQuery.initial());
    final b = await n.add('B', const NoteQuery.initial());
    await n.move(a.id, -1);
    await n.move(b.id, 1);
    expect(await _names(c), ['0:A', '1:B']);
  });

  test('each write bumps settings.last_modified', () async {
    final c = await _make();
    final n = c.read(savedSearchesProvider.notifier);
    final a = await n.add('A', const NoteQuery.initial());
    final first = await _stamp();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await n.rename(a.id, 'A2');
    expect(await _stamp(), isNot(first));
  });

  test('a settings-bus rebuild keeps the list while it re-reads', () async {
    final c = await _make();
    final n = c.read(savedSearchesProvider.notifier);
    await n.add('A', const NoteQuery.initial());
    expect(c.read(savedSearchesProvider), hasLength(1));

    c.read(settingsBusProvider.notifier).bump();
    // Synchronously after the bump: the previous list, not a transient [].
    expect(c.read(savedSearchesProvider), hasLength(1));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(savedSearchesProvider).map((s) => s.name), ['A']);
  });
}
