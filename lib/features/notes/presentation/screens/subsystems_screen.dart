import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_list_row.dart';
import '../../../../core/widgets/app_row_separator.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/subsystem_anchor.dart';

class SubsystemsScreen extends ConsumerWidget {
  const SubsystemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subsystemAnchorsProvider);
    return AppScaffold(
      title: 'Subsystems',
      slivers: async.when<List<Widget>>(
        loading: () => const [
          SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
        ],
        error: (e, _) => [
          SliverFillRemaining(child: Center(child: Text('Failed: $e'))),
        ],
        data: (anchors) => [
          if (anchors.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.widgets_outlined,
                message: 'No subsystems yet',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return const AppRowSeparator(indent: kRowInsetNoLeading);
                  }
                  final a = anchors[index ~/ 2];
                  return AppListRow(
                    title: Text(a.subject),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push(
                      '/notes/subsystems/${a.id}?name=${Uri.encodeComponent(a.subject)}',
                    ),
                  );
                },
                childCount: anchors.length * 2 - 1,
              ),
            ),
        ],
      ),
    );
  }
}
