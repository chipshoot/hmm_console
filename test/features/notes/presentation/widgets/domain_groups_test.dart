import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/presentation/widgets/domain_groups.dart';

NoteCatalog _cat(int id, String name) =>
    NoteCatalog(id: id, name: name, schema: '{}', formatType: 2, isDefault: false);

void main() {
  final catalogs = [
    _cat(10, 'Hmm.AutomobileMan.GasLog'),
    _cat(20, 'Hmm.AutomobileMan.AutomobileInfo'),
    _cat(30, 'General'),
  ];

  test('groups automobile catalogs together and keeps General separate', () {
    final groups = groupByDomain(catalogs, const {}, const {});
    final auto = groups.firstWhere((g) => g.key == 'AutomobileMan');
    expect(auto.catalogIds, {10, 20});
    expect(auto.style.displayName, 'Automobile');
    expect(groups.any((g) => g.key == 'General'), isTrue);
  });

  test('orders by usage first, then by aggregate note count', () {
    // General has more notes, but Automobile is used more often -> first.
    final byCount = groupByDomain(catalogs, const {30: 9, 10: 1}, const {});
    expect(byCount.first.key, 'General'); // no usage -> note count wins

    final byUsage =
        groupByDomain(catalogs, const {30: 9, 10: 1}, const {'AutomobileMan': 3});
    expect(byUsage.first.key, 'AutomobileMan'); // usage overrides count
  });
}
