import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/core/navigation/router_config.dart';

void main() {
  test(
    '/notes/deleted is declared before /notes/:id, so it is not a note id',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final router = c.read(routerConfig);
      addTearDown(router.dispose);
      final notes = router.configuration.routes
          .whereType<GoRoute>()
          .singleWhere((r) => r.path == '/notes');
      final paths = notes.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();
      expect(paths, contains('deleted'));
      expect(paths.indexOf('deleted'), lessThan(paths.indexOf(':id')));
      final deleted = notes.routes.whereType<GoRoute>().singleWhere(
        (r) => r.path == 'deleted',
      );
      expect(deleted.name, RouterNames.notesRecentlyDeleted.name);
    },
  );
}
