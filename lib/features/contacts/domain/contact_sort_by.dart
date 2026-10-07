// lib/features/contacts/domain/contact_sort_by.dart

/// "Sort contacts by" (Settings). Stored by `name` in prefs and the synced
/// settings bundle. NEVER localize.
enum ContactSortBy {
  family,
  given;

  /// Absent, unknown or wrong-typed values read as [family] (the default).
  static ContactSortBy fromName(Object? name) =>
      name == ContactSortBy.given.name ? given : family;
}
