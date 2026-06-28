import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/launcher_destination.dart';
import '../domain/launcher_input_mode.dart';
import '../domain/launcher_matcher.dart';
import '../domain/launcher_registry.dart';
import '../providers/launcher_prefs_provider.dart';
import '../providers/launcher_recents_provider.dart';
import 'launcher_navigation.dart';

/// Full-screen function-search route. A leading '/' enters command
/// mode (fuzzy-match destinations); plain text is the assistant stub;
/// empty input (or a lone '/') shows the favorites/recents landing.
class LauncherSearchScreen extends ConsumerStatefulWidget {
  const LauncherSearchScreen({super.key});

  @override
  ConsumerState<LauncherSearchScreen> createState() => _LauncherSearchScreenState();
}

class _LauncherSearchScreenState extends ConsumerState<LauncherSearchScreen> {
  final _controller = TextEditingController();
  String _raw = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go(LauncherDestination d) async {
    await ref.read(launcherRecentsProvider.notifier).record(d.id);
    if (!mounted) return;
    await launchDestination(context, ref, d);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(launcherPrefsProvider);
    final mode = modeOf(_raw);

    Widget body;
    switch (mode) {
      case LauncherInputMode.assistant:
        body = _assistantStub(context);
      case LauncherInputMode.empty:
        body = _landing(prefs.favorites);
      case LauncherInputMode.command:
        final q = commandQuery(_raw);
        if (q.isEmpty) {
          body = _landing(prefs.favorites);
        } else {
          final results = match(q, registry: launcherDestinations, aliases: prefs.aliases);
          body = results.isEmpty
              ? _empty('No matching features')
              : ListView(children: [for (final d in results) _tile(d)]);
        }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (v) => setState(() => _raw = v),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Type / for features · ask AI (soon)',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _tile(LauncherDestination d) => ListTile(
        leading: Icon(d.icon),
        title: Text(d.title),
        onTap: () => _go(d),
      );

  Widget _landing(List<String> favoriteIds) {
    final favorites = favoriteIds
        .map((id) => launcherDestinationsById[id])
        .whereType<LauncherDestination>()
        .toList();
    final recents = ref
        .watch(launcherRecentsProvider)
        .map((id) => launcherDestinationsById[id])
        .whereType<LauncherDestination>()
        .toList();

    if (favorites.isEmpty && recents.isEmpty) {
      return _empty('Type / to jump to a feature');
    }
    return ListView(children: [
      if (favorites.isNotEmpty) ...[
        _header('Favorites'),
        for (final d in favorites) _tile(d),
      ],
      if (recents.isNotEmpty) ...[
        _header('Recent'),
        for (final d in recents) _tile(d),
      ],
    ]);
  }

  Widget _assistantStub(BuildContext context) => Center(
        key: const Key('assistant-stub'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome,
                  size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text(
                'Ask the assistant — coming soon.\nType / to jump to a feature.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _empty(String text) => Center(
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
