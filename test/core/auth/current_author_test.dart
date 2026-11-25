import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/auth/current_author_account_name_provider.dart';
import 'package:hmm_console/core/auth/owner_id.dart';
import 'package:hmm_console/core/data/local/database.dart';

void main() {
  test('current author resolves with nobody signed in', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        hmmDatabaseProvider.overrideWithValue(db),
        ownerIdProvider.overrideWith((ref) async => 'OWNER'),
      ],
    );
    addTearDown(container.dispose);

    final author = await container.read(currentAuthorProvider.future);

    expect(author.accountName, 'OWNER');
  });
}
