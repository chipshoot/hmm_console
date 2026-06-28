import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/launcher_destination.dart';
import '../domain/launcher_registry.dart';
import '../providers/launcher_prefs_provider.dart';

/// Settings-reached screen to pin/unpin favorites, reorder pinned
/// favorites, and manage alias -> destination rows.
class LauncherManageScreen extends ConsumerStatefulWidget {
  const LauncherManageScreen({super.key});

  @override
  ConsumerState<LauncherManageScreen> createState() => _LauncherManageScreenState();
}

class _LauncherManageScreenState extends ConsumerState<LauncherManageScreen> {
  final _aliasController = TextEditingController();
  String? _aliasDestId;
  String? _aliasError;

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  /// ReorderableListView reports a `newIndex` that is one past the
  /// removed slot when dragging downward; normalize before moving.
  Future<void> _reorderFavorites(List<String> favorites, int oldIndex, int newIndex) async {
    final next = [...favorites];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    await ref.read(launcherPrefsProvider.notifier).setFavorites(next);
  }

  Future<void> _addAlias() async {
    final alias = _aliasController.text.trim().toLowerCase();
    final destId = _aliasDestId;
    final existing = ref.read(launcherPrefsProvider).aliases;
    if (alias.isEmpty || destId == null) {
      setState(() => _aliasError = 'Enter an alias and pick a destination');
      return;
    }
    if (existing.containsKey(alias)) {
      setState(() => _aliasError = 'Alias "$alias" already exists');
      return;
    }
    await ref.read(launcherPrefsProvider.notifier).addAlias(alias, destId);
    if (!mounted) return;
    setState(() {
      _aliasController.clear();
      _aliasDestId = null;
      _aliasError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(launcherPrefsProvider);

    final pinned = prefs.favorites
        .map((id) => launcherDestinationsById[id])
        .whereType<LauncherDestination>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Launcher')),
      body: ListView(
        children: [
          if (pinned.length > 1) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Pinned (drag to reorder)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ReorderableListView(
              key: const Key('pinned-reorder'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (o, n) => _reorderFavorites(prefs.favorites, o, n),
              children: [
                for (final d in pinned)
                  ListTile(
                    key: ValueKey('pinned-${d.id}'),
                    leading: Icon(d.icon),
                    title: Text(d.title),
                    trailing: const Icon(Icons.drag_handle),
                  ),
              ],
            ),
            const Divider(),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Favorites', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final d in launcherDestinations)
            ListTile(
              leading: Icon(d.icon),
              title: Text(d.title),
              trailing: IconButton(
                key: Key('fav-toggle-${d.id}'),
                icon: Icon(prefs.favorites.contains(d.id) ? Icons.star : Icons.star_border),
                onPressed: () =>
                    ref.read(launcherPrefsProvider.notifier).toggleFavorite(d.id),
              ),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Aliases', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final entry in prefs.aliases.entries)
            ListTile(
              title: Text('"${entry.key}"  →  ${launcherDestinationsById[entry.value]?.title ?? entry.value}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(launcherPrefsProvider.notifier).removeAlias(entry.key),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('alias-text'),
                  controller: _aliasController,
                  decoration: const InputDecoration(
                    labelText: 'New alias (e.g. cs)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('alias-dest'),
                  initialValue: _aliasDestId,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final d in launcherDestinations)
                      DropdownMenuItem(value: d.id, child: Text(d.title)),
                  ],
                  onChanged: (v) => setState(() => _aliasDestId = v),
                ),
                if (_aliasError != null) ...[
                  const SizedBox(height: 8),
                  Text(_aliasError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const Key('alias-add'),
                    onPressed: _addAlias,
                    icon: const Icon(Icons.add),
                    label: const Text('Add alias'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
