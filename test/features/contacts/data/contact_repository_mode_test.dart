import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/local_contact_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/data/i_contact_repository.dart';

import 'contact_repository_fakes.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

ProviderContainer _c(DataMode m) => ProviderContainer(overrides: [
      dataModeProvider.overrideWith(() => _Mode(m)),
      localContactRepositoryProvider.overrideWithValue(
          LocalContactRepository(FakeNoteRepository(), FakeCatalogRepository())),
    ]);

void main() {
  test('local and cloudStorage resolve the local repository', () {
    for (final m in [DataMode.local, DataMode.cloudStorage]) {
      final c = _c(m);
      addTearDown(c.dispose);
      expect(c.read(contactRepositoryModeProvider),
          isA<LocalContactRepository>());
    }
  });

  test('cloudApi throws the recognisable ContactsCloudApiUnavailable', () {
    final c = _c(DataMode.cloudApi);
    addTearDown(c.dispose);
    Object? caught;
    try {
      c.read(contactRepositoryModeProvider);
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(isContactsCloudApiUnavailable(caught!), isTrue);
    expect(isContactsCloudApiUnavailable(StateError('x')), isFalse);
  });
}
