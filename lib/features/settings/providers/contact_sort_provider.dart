// lib/features/settings/providers/contact_sort_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../contacts/domain/contact_sort_by.dart';
import '../data/syncable_settings_repository.dart';
import 'settings_bus_provider.dart';

/// "Sort contacts by". Same shape as `SyncSettingsNotifier`: a synchronous
/// default, then hydrated from prefs; re-read when a pulled settings bundle
/// bumps the bus.
class ContactSortByNotifier extends Notifier<ContactSortBy> {
  @override
  ContactSortBy build() {
    ref.watch(settingsBusProvider);
    _load();
    return ContactSortBy.family;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = ContactSortBy.fromName(
        prefs.getString(SyncableSettingsRepository.contactSortKey),
      );
    } catch (e) {
      // Type only. The list keeps sorting by family name.
      debugPrint('ContactSortBy: setting unreadable (${e.runtimeType})');
    }
  }

  Future<void> set(ContactSortBy value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SyncableSettingsRepository.contactSortKey, value.name);
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final contactSortByProvider =
    NotifierProvider<ContactSortByNotifier, ContactSortBy>(
  ContactSortByNotifier.new,
);
