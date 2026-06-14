import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/subsystem_anchor.dart';

class SubsystemsScreen extends ConsumerWidget {
  const SubsystemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subsystemAnchorsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subsystems')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed: $e')),
        data: (anchors) => ListView(
          children: [
            for (final a in anchors)
              ListTile(
                title: Text(a.subject),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                    '/notes/subsystems/${a.id}?name=${Uri.encodeComponent(a.subject)}'),
              ),
          ],
        ),
      ),
    );
  }
}
