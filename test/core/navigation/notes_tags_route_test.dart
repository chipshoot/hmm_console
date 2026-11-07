import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/core/navigation/router_config.dart';

void main() {
  test(
    '/notes/tags builds ManageTagsScreen and /notes/5 still opens a note',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final router = c.read(routerConfig);
      addTearDown(router.dispose);
      final notes = router.configuration.routes
          .whereType<GoRoute>()
          .singleWhere((r) => r.path == '/notes');
      final routes = notes.routes.whereType<GoRoute>().toList();
      final paths = routes.map((r) => r.path).toList();
      expect(paths.indexOf('tags'), isNonNegative);
      expect(paths.indexOf('tags'), lessThan(paths.indexOf(':id')));
      final tags = routes.singleWhere((r) => r.path == 'tags');
      expect(tags.name, RouterNames.notesManageTags.name);
      final note = routes.singleWhere((r) => r.path == ':id');
      expect(note.name, RouterNames.noteDetail.name);
      expect(
        router.configuration.namedLocation(RouterNames.notesManageTags.name),
        '/notes/tags',
      );
      expect(
        router.configuration.namedLocation(
          RouterNames.noteDetail.name,
          pathParameters: {'id': '5'},
        ),
        '/notes/5',
      );
    },
  );
}
