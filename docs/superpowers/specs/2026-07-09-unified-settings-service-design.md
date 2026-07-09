# Unified Device-Local Settings Service — Design

**Date:** 2026-07-09
**Status:** Approved (pending implementation plan)
**Repo:** `hmm_console` (client only)

## Problem

Device-local configuration is read/written directly from `SharedPreferences`
in ~12 scattered places across features (`data_mode`, `cloud_provider`,
`geo_capture_enabled`, `receipt_extractor_mode`, launcher recents, notes
filter usage, dashboard intro card, onboarding, sync network policy, local db
path, cloudStorage vault path). There is no single typed representation, no
central persistence owner, and no schema/versioning. The goal is one central,
typed configuration surface — the "settings.json" model — without
destabilizing the two tiers that already work (roaming preferences and
secrets).

## Goal & principle

Consolidate the **device-local** configuration behind one immutable typed
`AppSettings` model, persisted as a **single JSON blob** in
`SharedPreferences`, owned by one `SettingsController`. Existing per-setting
providers keep their public surface but become thin views over the
controller. Feature call sites do not change.

The three configuration tiers stay distinct:
- **Device-local** — this work: one `AppSettings` JSON blob.
- **Roaming preferences** — `SyncableSettings` (locale, launcher
  favorites/aliases, gas-log settings, sync settings). **Untouched.**
- **Secrets** — IDP / OneDrive tokens in secure storage. **Untouched.**

## Scope

**In scope**
- `AppSettings` immutable model + JSON (de)serialization + `schemaVersion`.
- `SettingsController` (`Notifier<AppSettings>`) as the single persistence
  owner (one `SharedPreferences` key: `app_settings`).
- One-time migration of the legacy device-local keys into the blob. Legacy
  keys are **retained** this release as a safety net (removal deferred to a
  later release).
- Re-pointing the existing device-local providers to read/write through the
  controller while preserving their public surfaces.

**Out of scope (future)**
- Folding `SyncableSettings` (roaming tier) into the same model.
- A user-editable / exportable `settings.json` file on disk, and import/export
  UI.
- Moving any secret into the blob (never).
- Migrating call sites off the per-setting providers (a later cleanup).

## System-level impact (analysis)

A scan of both `hmm` (backend/IdP) and `hmm_console` (client) confirms this
change is **client-only**:

- **Backend API — no impact.** Roaming settings sync via
  `GET/PUT /v1/profile/settings`, backed by `AuthorSettings.SettingsJson`,
  which the server stores **verbatim as opaque text** (never parsed). The
  roaming payload (`SyncableSettings.toJson`) carries only `gasLog`,
  `syncSettings`, `localeCode`, `launcher` — none of the device-local keys.
  No DTO/controller/schema change.
- **Backend IdP — no impact.** `Hmm.Idp` is identity/auth only; no
  user-settings storage.
- **Multi-device — no impact, correct by design.** Device-local settings are
  intentionally per-device and never sync; each device configures its own
  connection to the shared cloud location. Roaming happens only through the
  untouched `SyncableSettings` path.

**Connection-critical fields.** Three device-local settings *define which
backend a device talks to*: `dataMode`, `cloudProvider`, and
`cloudStorageVaultPath`. Losing or defaulting any of these silently reverts a
device to the `local` store, so it *appears* to lose cloud data (the data is
safe server-side / in OneDrive — the device is just reading the wrong store).
These fields get extra care in migration and error handling below.

## The boundary — what belongs in `AppSettings`

**Rule:** a key moves into `AppSettings` only if it is device-local **and has
no roaming counterpart**, so the sync layer stays stable.

**In `AppSettings` (device-local, no roaming counterpart):**

| Field | Legacy key | Type |
|---|---|---|
| `dataMode` | `data_mode` | enum (`local`/`cloudStorage`/`cloudApi`) |
| `cloudProvider` | `cloud_provider` | enum |
| `geoCaptureEnabled` | `geo_capture_enabled` | bool |
| `receiptExtractorMode` | `receipt_extractor_mode` | enum |
| `receiptCloudConsent` | receipt consent key | bool |
| `launcherRecents` | `launcher_recents` | list<string> |
| `notesFilterUsage` | `notes.filter_usage` | map<string,int> |
| `dashboardIntroCardSeen` | `dashboard_intro_card_seen` | bool |
| `onboardingCompleted` | `onboarding_completed` | bool |
| `syncNetworkPolicy` | `sync.network_policy` | enum/string |
| `localDbPath` | `local_db_path` | string? |
| `cloudStorageVaultPath` | cloudStorage vault path key | string? |

**Excluded (stay in the roaming tier — moving them would destabilize sync):**
- `app_locale` — locale roams via `SyncableSettings.localeCode`.
- Launcher **favorites/aliases** — roam via `SyncableSettings.launcher`.
- Gas-log settings, sync settings — roam via `SyncableSettings`.

The exact legacy key strings and enum/serialization details are read from the
current provider files during implementation; each field's default matches the
current provider's default.

## Components

- **`lib/core/settings/app_settings.dart`** — immutable model. Typed fields
  (above), `int schemaVersion`, `const AppSettings.defaults`,
  `AppSettings.fromJson(Map)`, `Map toJson()`, `copyWith(...)`. `fromJson`
  ignores unknown keys and fills missing keys with defaults
  (forward/backward-compatible).
- **`lib/core/settings/settings_controller.dart`** — `Notifier<AppSettings>`
  exposed as `settingsProvider`. On build: read the `app_settings` blob; if
  present decode it (corrupt → defaults, logged); if absent run migration;
  else `AppSettings.defaults`. Typed mutators (`setDataMode`,
  `setGeoCaptureEnabled`, `setReceiptExtractorMode`, …) each `copyWith` the
  current state and persist the whole blob. The single owner serializes
  writes, so there is no blob race.
- **`lib/core/settings/settings_migration.dart`** — pure-ish helper:
  `AppSettings migrateFromLegacy(SharedPreferences)` reads each legacy key
  into an `AppSettings`; the controller then writes the blob. Legacy keys are
  **retained** this release (removal deferred), and `migrateFromLegacy`
  doubles as the fallback source for connection-critical fields on a corrupt
  blob. Guarded so it runs once (only when no blob exists). Keyed off
  `schemaVersion` for future migrations.
- **Delegating providers** (public surface preserved; internals re-pointed to
  the controller):
  - `lib/core/data/data_mode.dart` (`DataModeNotifier`, `cloud_provider`)
  - `lib/features/settings/providers/geo_capture_provider.dart`
  - `lib/features/receipt_scan/providers/receipt_extractor_providers.dart`
    (mode + consent)
  - `lib/features/launcher/providers/launcher_recents_provider.dart`
  - `lib/features/notes/states/filter_usage.dart`
  - `lib/features/dashboard/providers/intro_card_provider.dart`
  - `lib/features/onboarding/providers/onboarding_provider.dart`
  - `lib/features/settings/providers/sync_settings_provider.dart` (network
    policy only — the roaming `SyncSettings` is untouched)
  - the `local_db_path` and cloudStorage vault-path owners

  Each keeps its provider name/type and method signatures; reads become
  `ref.watch(settingsProvider.select((s) => s.<field>))` and writes call
  `ref.read(settingsProvider.notifier).<setter>(...)`. Any per-setting
  behavior (e.g. `DataMode`'s legacy-value mapping, locale side-effects) is
  preserved in the delegating provider.

## Data flow

```
Read:  ref.watch(dataModeProvider)
         -> DataModeNotifier returns ref.watch(settingsProvider).dataMode
Write: ref.read(dataModeProvider.notifier).setMode(x)
         -> ref.read(settingsProvider.notifier).setDataMode(x)
         -> copyWith -> persist blob (app_settings) -> notify
         -> dataModeProvider re-emits
```

## Migration

On first `SettingsController` build after the update:
1. If `app_settings` blob exists → decode and use it (skip migration).
2. Else read the legacy keys via `migrateFromLegacy`, build `AppSettings`
   (missing keys → defaults), and write the blob.
3. Set `schemaVersion` to the current version.

**Legacy keys are NOT deleted in this release** (refinement #1). They are
left in place for one release as a reversible safety net, and
`migrateFromLegacy` remains available as a fallback source for the
connection-critical fields (below). A later release removes them once the
blob is proven in the field. Migration is still idempotent — once the blob
exists it is the source of truth and migration does not re-run.

## Error handling

- Corrupt / undecodable blob → log; fall back to `AppSettings.defaults` for
  ordinary fields, but for the **connection-critical fields** (`dataMode`,
  `cloudProvider`, `cloudStorageVaultPath`) prefer, in order: any value still
  decodable from the partial blob → the legacy keys (still present this
  release) → only then the default (refinement #2). This prevents a corrupt
  blob from silently dropping a device to the `local` store. Never crash.
- Missing legacy key during migration → that field's default.
- Persist failure (`setString` throws) → keep the in-memory value, log;
  the next successful write reconciles.
- Migration is guarded by blob presence + `schemaVersion` so it runs exactly
  once.

## Testing

- **`AppSettings`**: `fromJson`/`toJson` round-trip; `defaults`; unknown-key
  tolerance; missing-key defaults; `copyWith` per field.
- **Migration**: legacy keys set → correct `AppSettings`; legacy keys are
  **retained** (not deleted) this release; blob present → migration skipped;
  partial legacy keys → defaults for the rest.
- **Connection-critical migration matrix** (refinement #3): a table-driven
  test that every legacy value of `dataMode`, `cloudProvider`, and
  `cloudStorageVaultPath` round-trips into the blob and back unchanged
  (e.g. `data_mode` = each of `local`/`cloudStorage`/`cloudApi`/legacy `api`,
  a set `cloud_provider`, and a non-null vault path).
- **Corrupt-blob connection-critical fallback**: a decode-failure blob with
  legacy keys still present yields the legacy `dataMode`/`cloudProvider`/
  `cloudStorageVaultPath`, not the defaults.
- **`SettingsController`**: empty prefs → defaults; a `setX` persists the blob
  and re-emits; corrupt blob → defaults without throwing.
- **Delegating providers** (representative — `DataMode` and one bool, e.g.
  onboarding): reading the provider reflects the controller's value; the
  provider's mutator routes through the controller and persists.

## Rollout

Single client change, additive and backward-compatible: on first launch after
the update, existing users' scattered keys migrate into the blob transparently
(no data loss, no re-onboarding). Legacy keys are retained this release as a
reversible safety net; a later release deletes them once the blob is proven.
No backend, IdP, or device-pairing involvement (see System-level impact).
