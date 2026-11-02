import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/presentation/widgets/domain_groups.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

NoteCatalog _cat(int id, String name) => NoteCatalog(
  id: id,
  name: name,
  schema: '{}',
  formatType: 0,
  isDefault: false,
);

void main() {
  const gasLogId = 2;
  final groups = [
    DomainGroup('AutomobileMan', [
      _cat(1, 'Hmm.AutomobileMan.AutomobileInfo'),
      _cat(gasLogId, 'Hmm.AutomobileMan.GasLog'),
    ], 0),
    DomainGroup('General', [_cat(3, 'General')], 0),
  ];
  final autoGroup = groups.first;

  test('catalog selection maps to a domain source and back', () {
    expect(sourceForCatalogSelection(null, groups), const AllSource());
    expect(sourceForCatalogSelection({}, groups), const AllSource());
    expect(
      sourceForCatalogSelection(autoGroup.catalogIds, groups),
      const DomainSource(key: 'AutomobileMan'),
    );
    expect(
      sourceForCatalogSelection({gasLogId}, groups),
      const DomainSource(key: 'AutomobileMan', catalogId: gasLogId),
    );
    expect(sourceForCatalogSelection({1, 3}, groups), const AllSource());
    expect(sourceForCatalogSelection({99}, groups), const AllSource());

    expect(
      catalogSelectionFor(
        const DomainSource(key: 'AutomobileMan', catalogId: gasLogId),
        groups,
      ),
      {gasLogId},
    );
    expect(
      catalogSelectionFor(const DomainSource(key: 'AutomobileMan'), groups),
      autoGroup.catalogIds,
    );
    expect(catalogSelectionFor(const AllSource(), groups), isNull);
  });
}
