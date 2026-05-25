/// Network gate for the auto-sync controller (Phase C of the cloud-sync
/// improvements). Manual "Sync now" taps respect this too, but route
/// through a confirm dialog before bypassing — decision C1 in
/// `task_plan.md`.
enum SyncNetworkPolicy {
  /// Default. Auto-sync only fires when the device reports a WiFi
  /// connection. Cellular and "no network" both block.
  wifiOnly,

  /// Auto-sync may fire on any connection type the device reports
  /// (WiFi, cellular, ethernet, satellite, etc.). The user is on the
  /// hook for cellular data costs.
  anyNetwork,
}

/// Value object backing the `syncSettingsProvider`. Persisted to
/// shared_preferences as a single key (the enum name); a value-type
/// wrapper keeps the door open for future settings (e.g. periodic
/// interval override, retry-budget) without changing the storage key
/// or the provider shape.
class SyncSettings {
  const SyncSettings({
    this.networkPolicy = SyncNetworkPolicy.wifiOnly,
  });

  final SyncNetworkPolicy networkPolicy;

  SyncSettings copyWith({SyncNetworkPolicy? networkPolicy}) =>
      SyncSettings(networkPolicy: networkPolicy ?? this.networkPolicy);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncSettings && other.networkPolicy == networkPolicy);

  @override
  int get hashCode => networkPolicy.hashCode;
}
