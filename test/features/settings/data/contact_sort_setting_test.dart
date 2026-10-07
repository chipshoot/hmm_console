// test/features/settings/data/contact_sort_setting_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:hmm_console/features/settings/providers/contact_sort_provider.dart';
import 'package:hmm_console/features/settings/providers/settings_bus_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SyncableSettings.contactSortBy', () {
    test('an old bundle without the key reads as family', () {
      final s = SyncableSettings.fromJson({'_v': 1});
      expect(s.contactSortBy, ContactSortBy.family);
    });

    test('given round-trips; family is not written', () {
      final given = SyncableSettings.defaults().copyWith(
        contactSortBy: ContactSortBy.given,
      );
      expect(given.toJson()['contactSortBy'], 'given');
      expect(
        SyncableSettings.fromJsonString(given.toJsonString()).contactSortBy,
        ContactSortBy.given,
      );
      expect(
        SyncableSettings.defaults().toJson().containsKey('contactSortBy'),
        isFalse,
      );
    });

    test('an unknown value reads as family', () {
      expect(
        SyncableSettings.fromJson({'contactSortBy': 'middle'}).contactSortBy,
        ContactSortBy.family,
      );
    });
  });

  group('SyncableSettingsRepository', () {
    test('reads and applies contacts.sort_by', () async {
      final repo = SyncableSettingsRepository();
      expect((await repo.read()).contactSortBy, ContactSortBy.family);
      await repo.apply(
        (await repo.read()).copyWith(contactSortBy: ContactSortBy.given),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('contacts.sort_by'), 'given');
      expect((await repo.read()).contactSortBy, ContactSortBy.given);
    });
  });

  group('contactSortByProvider', () {
    test('defaults to family, loads, sets and bumps the stamp', () async {
      SharedPreferences.setMockInitialValues({'contacts.sort_by': 'given'});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(contactSortByProvider, (_, _) {});
      addTearDown(sub.close);
      expect(c.read(contactSortByProvider), ContactSortBy.family);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(contactSortByProvider), ContactSortBy.given);

      await c.read(contactSortByProvider.notifier).set(ContactSortBy.family);
      expect(c.read(contactSortByProvider), ContactSortBy.family);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('contacts.sort_by'), 'family');
      expect(prefs.getString('settings.last_modified'), isNotNull);
    });

    test('a remote pull (settings bus) re-reads the value', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(contactSortByProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('contacts.sort_by', 'given');
      c.read(settingsBusProvider.notifier).bump();
      c.read(contactSortByProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(contactSortByProvider), ContactSortBy.given);
    });
  });
}
