# Login-free Local and Cloud-storage Tiers (#49) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In `local` and `cloudStorage` modes Hmm opens straight to the device's data with no Hmm login; only `cloudApi` keeps the login gate.

**Architecture:** A device-fixed **owner id** (prefs, created once) replaces the signed-in user's IdP `sub` as the key for local data and for the OneDrive folder. The router's auth gate becomes one derived bool, `loginRequiredProvider` (`cloudApi` and signed out), so signing in or out in the other modes never rebuilds the router. Server features call one `ensureHmmSignedIn` sheet. A device→Hmm-account link (`linkedHmmSub`) guards against a second account.

**Tech Stack:** Flutter, Riverpod, GoRouter, Drift, SharedPreferences, Dio + http_mock_adapter (tests), gen-l10n (en/zh).

**Spec:** `docs/superpowers/specs/2026-11-24-login-free-tiers-design.md` (approved 2026-11-25), which updates `docs/superpowers/specs/2026-09-17-three-tier-login-design.md`.

## Global Constraints

- No login in `local` and `cloudStorage`; login only for `cloudApi` (D1).
- The owner id never changes once stored. Existing installs keep their current id, the IdP `sub` (D2). The single exception is OneDrive folder adoption (§4.4, Task 5).
- The OneDrive layout `approot/users/{id}/` stays. No data migration, and no note changes owner.
- The owner id is never sent to the server. `cloudApi` pushes keep using the server's author (`ApiSyncProvider._resolveAuthorId`, unchanged).
- Server features are never hidden and never opened to anonymous callers: they ask to sign in (D5).
- Profile = the existing "Me" contact (`isSelf`). No separate profile store (D3).
- Prefs keys are device-local and never part of `SyncableSettings`: `hmm.ownerId`, `hmm.linkedHmmSub`, `hmm.linkedHmmEmail`.
- iOS uses Cupertino action sheets and dialogs, other platforms Material (CLAUDE.md Platform UI Rules). Icon buttons use `HmmIconButton`.
- Every new string goes in `app_en.arb` and `app_zh.arb`, then gen-l10n regenerates.
- No new package dependencies.
- Run `dart format` on individual files only, never on a directory.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Decisions made in this plan (builder's calls inside the spec)

- **More than one `Authors` row at upgrade (extends §4.3).** Use the row owning the most notes, not a new UUID. A new UUID would hide every existing note, because `LocalHmmNoteRepository` filters reads by author.
- **Reading the old `sub` offline.** Decode the *stored* access token even when it has expired (`peekStoredSub`). Never refresh over the network. An upgrade with no network must still find the old id.
- **How adoption works (§4.4).** Rename the current owner's `Authors.accountName` to the adopted folder name and store it as the owner id. The author row id is unchanged, so no note changes owner, even when local notes already exist.
- **Exchange rates load passively** (the gas log list), so they get no pop-up sheet. Signed out, they show a one-line "Sign in to Hmm to convert currencies" hint that opens the sheet.
- **cloudStorage auth failure.** The dashboard's "Sign in again" fix becomes the OneDrive sign-in. OneDrive no longer needs a Hmm token. `cloudApi` keeps Hmm sign-out → login.
- **Login screen exit.** When pushed (from a sheet or onboarding), it pops `true` on success. When reached by the `cloudApi` redirect, the router rebuild takes over, as today.
- **Help entries.** Settings, onboarding and login have no help entries today, and this plan adds no screen, so no help entries change.

## Review Focus

1. Upgrade where the tokens were cleared earlier and the DB has two `Authors` rows → the owner id is the row with the notes, and every note is still listed (Task 1 test).
2. Upgrade with an expired access token and no network → the owner id is that token's `sub` with no network call (Task 1 test).
3. Signing in from a server-feature sheet in `local` → you are back on the same screen, and the router is not rebuilt (Task 3 router test).
4. New device that already has local notes switches to OneDrive, and OneDrive has exactly one folder → the folder is adopted, the local notes stay visible, and no second folder is created (Task 5 test).
5. Settings mode switch to `cloudApi`, sign-in cancelled → the mode is unchanged and the dropdown shows the old mode (Task 7 test).

---

### Task 1: Owner id store and resolution

**Files:**
- Create: `lib/core/auth/owner_id.dart`
- Modify: `lib/core/network/idp_token_service.dart` (add `peekStoredSub`, `peekStoredEmail`, `hasHmmSession`)
- Test: `test/core/auth/owner_id_test.dart`, `test/core/network/idp_token_peek_test.dart`

**Interfaces:**
- Produces:
  - `class OwnerIdStore { OwnerIdStore(SharedPreferences prefs); String? get ownerId; Future<void> setOwnerIdOnce(String id); Future<void> adoptOwnerId(String id); String? get linkedHmmSub; String? get linkedHmmEmail; Future<void> setLink(String sub, String? email); }`
  - `setOwnerIdOnce` throws `StateError` if an id is already stored. `adoptOwnerId` is the only overwrite and is used only by Task 5.
  - `final ownerIdStoreProvider = FutureProvider<OwnerIdStore>`.
  - `final ownerIdProvider = FutureProvider<String>`: the resolved owner id, which never throws for "signed out".
  - `Future<String> resolveOwnerId({required OwnerIdStore store, required String? signedInSub, String? signedInEmail, required Future<String?> Function() peekStoredSub, required Future<String?> Function() peekStoredEmail, required IAuthorRepository authors, required Future<Map<int, int>> Function() noteCountsByAuthor, required String Function() newId})`, pure and testable.
  - `IdpTokenService`: `Future<String?> peekStoredSub()` and `Future<String?> peekStoredEmail()`: decode the stored access token, expired or not, with no refresh. They return null when there is no token or it can't be decoded. `Future<bool> hasHmmSession()` is true when a refresh token is stored.

Resolution order (§4.3, plus the plan decision above):
1. A stored owner id → return it.
2. Else the signed-in `sub`.
3. Else `peekStoredSub()`.
4. Else the one active `Authors` row's `accountName`; with several rows, the row with the most notes (ties go to the lowest id).
5. Else `newId()` (a UUID v4 from `lib/core/util/uuid.dart`).

The result is stored with `setOwnerIdOnce`. When it came from steps 2–4, `setLink(id, email)` is also called, with the email from the signed-in user or `peekStoredEmail()`, else null (§4.10 "Existing installs").

- [ ] **Step 1: Write the failing tests** in `owner_id_test.dart`:
  - `stored id wins over everything`: store `'A'`, signedInSub `'B'` → `'A'`.
  - `signed-in sub is used and linked`: → `'SUB'`, then `store.ownerId == 'SUB'` and `store.linkedHmmSub == 'SUB'`.
  - `expired token sub used when signed out`: signedInSub null, peek → `'OLD'` → `'OLD'` and linked.
  - `single author row`: peek null, one row `'ROW'` → `'ROW'`.
  - `several author rows picks the one with notes` (Review Focus 1): rows id1 `'X'` (0 notes) and id2 `'Y'` (12 notes) → `'Y'`.
  - `fresh install gets a new id and no link`: no rows → `newId()` result, `linkedHmmSub == null`.
  - `setOwnerIdOnce twice throws StateError`.
  - `adoptOwnerId overwrites`.
- [ ] **Step 2: Write `idp_token_peek_test.dart`**:
  - `peekStoredSub decodes an expired token without refreshing` (Review Focus 2): a token storage fake holds a JWT with `sub: 'S1'`, `exp` in the past and expiry in the past; the Dio adapter has no routes, so any network call fails the test → `'S1'`.
  - `hasHmmSession true only with a refresh token`.
- [ ] **Step 3: Run both test files.** Expected: FAIL (the symbols are undefined).
- [ ] **Step 4: Implement the code.**
  - `noteCountsByAuthor` in the provider is one Drift query counting non-deleted notes grouped by author id (use the real table and column names from `database.dart`).
  - `ownerIdProvider` reads `currentUserProvider` once (`ref.read`, not watch), because the id must not follow a login.
- [ ] **Step 5: Run the tests.** Expected: PASS.
- [ ] **Step 6: Commit** `feat(auth): device owner id resolved once, existing installs keep their sub (#49)`.

### Task 2: Local data keys off the owner id

**Files:**
- Modify: `lib/core/auth/current_author_account_name_provider.dart`: delete `currentAuthorAccountNameProvider`; `currentAuthorProvider` uses `await ref.watch(ownerIdProvider.future)` and `getOrCreateDefaultAuthor(ownerId)`.
- Modify: `lib/features/gas_log/presentation/screens/automobile_edit_screen.dart:1152`: the audit `actor` becomes `ref.read(ownerIdProvider).value`.
- Modify: `lib/features/auth/states/login_state.dart`: remove the `getOrCreateDefaultAuthor(user.uid)` call (the author now follows the owner id, not the login).
- Modify the tests that override `currentAuthorAccountNameProvider` or fake a login only to reach data: `test/core/data/local/local_hmm_note_repository_provider_wiring_test.dart`, `test/core/data/sync/pending_sync_count_provider_test.dart`, and any other file the analyzer flags. They switch to `ownerIdProvider.overrideWith((ref) async => '<same id they used>')`.
- Test: `test/core/auth/current_author_test.dart`

**Interfaces:**
- Consumes: `ownerIdProvider` (Task 1).
- Produces: `currentAuthorProvider` (same name and type, `FutureProvider<Author>`), now readable with nobody signed in.

- [ ] **Step 1: Write the failing test** `current author resolves with nobody signed in`: override `ownerIdProvider` → `'OWNER'` and leave `currentUserProvider` null → `author.accountName == 'OWNER'`.
- [ ] **Step 2: Run it.** Expected: FAIL with the StateError "read with no signed-in user".
- [ ] **Step 3: Implement the changes**, then fix every analyzer error from the deleted provider.
- [ ] **Step 4: Run `flutter analyze` and `flutter test test/core test/features/gas_log test/features/auth`.** Expected: analyze clean, tests PASS.
- [ ] **Step 5: Commit** `refactor(auth): local author follows the device owner id (#49)`.

### Task 3: Mode-aware login gate

**Files:**
- Create: `lib/core/navigation/login_gate.dart`
- Modify: `lib/core/navigation/router_config.dart` (redirect), `lib/core/navigation/onboarding_redirect.dart`, `lib/features/auth/presentation/screens/login_screen.dart` (exit on success)
- Test: `test/core/navigation/login_gate_test.dart`, `test/core/navigation/onboarding_redirect_test.dart` (update), `test/core/navigation/router_stability_test.dart` (add)

**Interfaces:**
- Produces:
  - `final loginRequiredProvider = Provider<bool>`: true only when settings have loaded, the mode is `cloudApi` and `routerAuthStateProvider` is not `true`.
  - `String? authGateRedirect({required bool loginRequired, required bool isAuthPath})`: returns `'/auth'` when the login is required and you're not already on `/auth`, else null.
  - `onboardingRedirect({required bool settingsLoaded, required bool onboardingCompleted, required bool isOnboardingPath, required bool isAuthPath})`: the `isAuthenticated` parameter is removed. It returns null on `/auth` paths, so onboarding's Hmm cloud option can push the login.

The router's redirect watches **only** `loginRequiredProvider`, and no longer `routerAuthStateProvider` or `dataModeProvider` directly. A sign-in or sign-out in `local`/`cloudStorage` leaves the bool unchanged, so the `GoRouter` is not rebuilt.

On success, the login screen's listener does `if (context.canPop()) context.pop(true);` and otherwise leaves the navigation to the router.

- [ ] **Step 1: Write the failing tests:**
  - `login_gate_test`: (local, signed out) → false; (cloudStorage, signed out) → false; (cloudApi, signed out) → true; (cloudApi, signed in) → false; (settings not loaded) → false. Also `authGateRedirect(loginRequired: true, isAuthPath: true)` → null.
  - `onboarding_redirect_test`: replace the `isAuthenticated` cases. A signed-out new install now goes to `/onboarding`, and `isAuthPath: true` → null.
  - `router_stability_test` adds `signing in while in local mode does not rebuild the router` (Review Focus 3): read `routerConfig`, flip the auth stream to true, and `expect(identical(before, after), isTrue)`. Also `signing out in cloudApi sends you to /auth`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement the code.**
- [ ] **Step 4: Run `flutter test test/core/navigation test/features/auth`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(nav): Hmm login required only in cloudApi (#49)`.

### Task 4: Onboarding as the front door

**Files:**
- Modify: `lib/features/onboarding/presentation/screens/onboarding_screen.dart`, the ARB files
- Test: `test/features/onboarding/onboarding_screen_test.dart` (new)

**Interfaces:**
- Consumes: the login screen's `pop(true)` (Task 3).
- Produces: a third `_Choice.hmmCloud`. Continue → `final ok = await context.push<bool>('/auth')`. If `ok == true`: `setMode(DataMode.cloudApi)`, `markCompleted()`, `context.go('/')`. Otherwise stay on the screen with no error.

ARB keys:

| Key | en | zh |
|---|---|---|
| `onboardingHmmCloud` | Hmm cloud (server) | Hmm 云（服务器） |
| `onboardingHmmCloudSubtitle` | Sign in or register a Hmm account; your data lives on the Hmm server. | 登录或注册 Hmm 账户；数据保存在 Hmm 服务器上。 |

- [ ] **Step 1: Write the failing tests:**
  - `three choices are shown`.
  - `Hmm cloud: login success switches to cloudApi and finishes`: a stub `/auth` route pops `true` → mode is `cloudApi` and onboarding is completed.
  - `Hmm cloud: login cancelled stays put`: the stub pops `null` → mode unchanged, still on onboarding.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run gen-l10n.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(onboarding): pick the tier first, Hmm cloud option (#49)`.

### Task 5: OneDrive folder without a Hmm login

**Files:**
- Create: `lib/core/data/sync/onedrive_owner_folder.dart`
- Modify: `lib/core/data/sync/onedrive_graph_client.dart`:
  - add `userFolderExists` and `listUserFolders`;
  - the provider passes the folder resolver;
  - the `_userPath` 401 message no longer says "Sign back in to the app".
- Modify: `lib/core/data/sync/onedrive_sync_provider.dart`: `migrateLegacyIfNeeded` uses the resolved folder id, not the claims `sub`.
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`: add the folder chooser row. Modify the ARB files.
- Test: `test/core/data/sync/onedrive_owner_folder_test.dart`, `test/core/data/sync/onedrive_migration_test.dart` (update)

**Interfaces:**
- Consumes: `OwnerIdStore.ownerId` and `adoptOwnerId` (Task 1), `ownerIdProvider`, `currentAuthorProvider`.
- Produces:
  - `typedef OneDriveUserFolder = ({String name, DateTime? modified});`
  - `OneDriveGraphClient.userFolderExists(String id) → Future<bool>` (GET `approot:/users/{enc(id)}`; 200 → true, 404 → false).
  - `OneDriveGraphClient.listUserFolders() → Future<List<OneDriveUserFolder>>` (GET `approot:/users:/children`, folders only, names starting with `.` skipped, `@odata.nextLink` followed).
  - `class OneDriveOwnerFolder { Future<String> resolve(); Future<void> choose(String name); }`, memoised per instance until `choose`.
  - `class OneDriveFolderChoiceRequired implements Exception { final List<OneDriveUserFolder> folders; }`.
  - `final oneDriveOwnerFolderProvider` and `final oneDriveFolderChoiceProvider = NotifierProvider<…, List<OneDriveUserFolder>?>` (set when `resolve` throws, cleared by `choose`).
  - The client keeps its `CurrentUserSubResolver` constructor parameter (13 tests build it with that). The provider passes `() => ref.read(oneDriveOwnerFolderProvider).resolve()`, read lazily to avoid a provider cycle. The typedef's doc comment now says "owner folder id".

`resolve()` (§4.4):
1. `userFolderExists(ownerId)` → ownerId.
2. Else `listUserFolders()`:
   - exactly one → adopt it;
   - none → ownerId (the first write creates the folder);
   - several → throw `OneDriveFolderChoiceRequired`.

**Adopt(name):**
1. If an `Authors` row named `name` already exists, throw `OneDriveFolderChoiceRequired([that folder])` so the person decides.
2. Otherwise rename the current owner's `Authors.accountName` to `name` with `updateAuthor`.
3. `store.adoptOwnerId(name)`.
4. `ref.invalidate(ownerIdProvider)`.

The orchestrator surfaces `OneDriveFolderChoiceRequired` as a sync error with the message `Several Hmm data folders found in OneDrive. Choose one in Settings.`

Settings row (cloudStorage, OneDrive signed in, `oneDriveFolderChoiceProvider` non-null): a ListTile with `oneDriveChooseFolderTitle`. It opens a Cupertino action sheet (iOS) or Material dialog listing each folder as `oneDriveFolderModified(date)`, with the folder name truncated to 8 characters as the title. Picking one calls `choose(name)`, then `triggerManualSync()`.

ARB keys:

| Key | en | zh |
|---|---|---|
| `oneDriveChooseFolderTitle` | Choose your Hmm data in OneDrive | 选择 OneDrive 中的 Hmm 数据 |
| `oneDriveFolderModified` | Last changed {date} | 最后修改 {date} |

- [ ] **Step 1: Write the failing tests** in `onedrive_owner_folder_test.dart` (DioAdapter as in `onedrive_graph_client_path_test.dart`; in-memory author repo):
  - `own folder exists → used, nothing renamed`.
  - `no own folder, one other folder → adopted` (Review Focus 4): local author `'NEW'` owns 3 notes, OneDrive lists `['IPHONE']` → `resolve() == 'IPHONE'`, `store.ownerId == 'IPHONE'`, the author row keeps its id with accountName `'IPHONE'`, and the 3 notes are still returned by `LocalHmmNoteRepository`.
  - `no folders → own id, nothing renamed`.
  - `several folders → OneDriveFolderChoiceRequired`, and `oneDriveFolderChoiceProvider` holds both.
  - `choose(name) adopts and clears the choice`.
  - `.legacy_migrated.json is not counted as a folder`.
  - `onedrive_migration_test`: the marker's `for_sub` is the resolved folder id, with no token stored.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run gen-l10n.
- [ ] **Step 4: Run `flutter test test/core/data/sync`.** Expected: PASS (the existing 13 client tests unchanged).
- [ ] **Step 5: Commit** `feat(sync): find the OneDrive folder without a Hmm login (#49)`.

### Task 6: "Sign in to Hmm" sheet in front of server features

**Files:**
- Create: `lib/features/auth/presentation/hmm_sign_in_sheet.dart`
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart` (`_scanReceipt`, Cloud AI mode only), `lib/features/gas_log/presentation/widgets/gas_station_form_dialog.dart` (`_captureLocation`, before `reverseGeocode`), `lib/features/gas_log/providers/exchange_rate_provider.dart`, `lib/features/gas_log/presentation/screens/gas_log_list_screen.dart`, the ARB files
- Test: `test/features/auth/hmm_sign_in_sheet_test.dart`, `test/features/gas_log/exchange_rate_sign_in_test.dart`

**Interfaces:**
- Consumes: `IdpTokenService.hasHmmSession` (Task 1), the login `pop(true)` (Task 3).
- Produces:
  - `Future<bool> ensureHmmSignedIn(BuildContext context, WidgetRef ref, {required String feature})`. If there's a session → true with no UI. Otherwise a sheet with title `hmmSignInSheetTitle(feature)`, body `hmmSignInSheetBody`, and Sign in / Cancel. Sign in → `context.push<bool>('/auth')` → returns `== true`.
  - `class HmmSignInRequired implements Exception {}`, thrown by `exchangeRateProvider` when `from != to` and there's no session.

Call sites:
- **Receipt scan:** in Cloud AI mode, `if (!await ensureHmmSignedIn(..., feature: l.hmmFeatureReceiptScan)) return;` runs before picking.
- **Address lookup:** GPS still fills the coordinates. The reverse-geocode runs only if `ensureHmmSignedIn(feature: l.hmmFeatureAddressLookup)` returns true. Otherwise the existing "no address" snackbar shows.
- **Gas log list:** when `rateAsync.error is HmmSignInRequired`, show a tappable line `gasLogRatesNeedSignIn` above the list. Tapping it calls `ensureHmmSignedIn(feature: l.hmmFeatureExchangeRates)`; on true, invalidate the provider.

ARB keys:

| Key | en | zh |
|---|---|---|
| `hmmSignInSheetTitle` | Sign in to Hmm to use {feature} | 登录 Hmm 以使用{feature} |
| `hmmSignInSheetBody` | Your data stays on this device. Signing in only unlocks this feature. | 你的数据仍保存在本设备上。登录只用于开启此功能。 |
| `hmmSignInAction` | Sign in | 登录 |
| `hmmFeatureReceiptScan` | Cloud AI receipt scan | 云端 AI 扫描收据 |
| `hmmFeatureAddressLookup` | address lookup | 地址查询 |
| `hmmFeatureExchangeRates` | exchange rates | 汇率 |
| `hmmFeatureCloud` | Hmm cloud | Hmm 云 |
| `gasLogRatesNeedSignIn` | Sign in to Hmm to convert currencies | 登录 Hmm 以换算货币 |

- [ ] **Step 1: Write the failing tests:**
  - `session present → true, no sheet`.
  - `no session → sheet; Cancel → false`.
  - `no session → Sign in → stub /auth pops true → true`.
  - `iOS shows CupertinoActionSheet` (`debugDefaultTargetPlatformOverride`).
  - `exchange rate signed out with different currencies throws HmmSignInRequired; same currency returns 1.0 with no session check`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run gen-l10n.
- [ ] **Step 4: Run `flutter test test/features/auth test/features/gas_log test/features/automobile_records`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(auth): server features ask to sign in to Hmm when used (#49)`.

### Task 7: Hmm account in Settings, sign-out and mode switch

**Files:**
- Create: `lib/features/settings/presentation/widgets/hmm_account_section.dart`
- Modify:
  - `settings_screen.dart`: mount the section above Data storage; the mode dropdown change goes through the guard.
  - `lib/features/dashboard/presentation/screens/dashboard_screen.dart`: remove Sign out from the user menu (both platforms); the sheet title shows `syncSheetSignedInAs(email)` only when an email is known; the auth-failure first action branches on mode.
  - the ARB files.
- Test: `test/features/settings/presentation/hmm_account_section_test.dart`, `test/features/settings/presentation/data_mode_switch_test.dart`, `test/features/dashboard/dashboard_user_menu_test.dart`

**Interfaces:**
- Consumes: `ensureHmmSignedIn` and `hmmFeatureCloud` (Task 6), `loginRequiredProvider` (Task 3).
- Produces:
  - `HmmAccountSection`, shown in every mode. Signed in: `settingsHmmSignedInAs(email)` with a Sign out button. Signed out: `settingsHmmNotSignedIn` with a Sign in button (`context.push('/auth')`).
  - `Future<bool> switchDataMode(BuildContext, WidgetRef, DataMode to)`. To `cloudApi` it requires `ensureHmmSignedIn(feature: l.hmmFeatureCloud)`, and false leaves the mode unchanged. Every other target switches straight away (§4.8).

**Sign-out:**
- In `local`/`cloudStorage`: `signOutUseCaseProvider.signOut()`, then `currentUserProvider.setUser(null)`, then the snackbar `settingsHmmSignedOut`. No navigation, and the data stays.
- In `cloudApi`: the same calls; the gate redirects to `/auth` (§4.6).

**Dashboard auth-failure fix:** `cloudApi` → Hmm `signOut()` (as today); `cloudStorage` → `oneDriveAuthProvider.signIn()`, then `ref.invalidate(oneDriveAuthStateProvider)`.

The dropdown is keyed on the current mode (`ValueKey(dataMode)`), so a cancelled switch redraws the old value.

ARB keys:

| Key | en | zh |
|---|---|---|
| `settingsHmmAccount` | Hmm account | Hmm 账户 |
| `settingsHmmSignedInAs` | Signed in as {email} | 已登录：{email} |
| `settingsHmmNotSignedIn` | Not signed in. Only needed for Hmm cloud and server features. | 未登录。仅 Hmm 云和服务器功能需要登录。 |
| `settingsHmmSignOut` | Sign out | 退出登录 |
| `settingsHmmSignedOut` | Signed out of Hmm. Your data stays on this device. | 已退出 Hmm。你的数据仍保存在本设备上。 |

- [ ] **Step 1: Write the failing tests:**
  - `section signed out shows Sign in; signed in shows email and Sign out`.
  - `sign-out in local mode stays on Settings and data stays` (the route is still `/settings` and `currentAuthorProvider` resolves the same owner).
  - `switch to cloudApi cancelled keeps the mode and the dropdown` (Review Focus 5).
  - `switch to cloudApi with a session switches`.
  - `switch from cloudApi to local needs no sign-in`.
  - Dashboard: `user menu has no Sign out`, and `cloudStorage auth failure offers OneDrive sign-in`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run gen-l10n.
- [ ] **Step 4: Run `flutter test test/features/settings test/features/dashboard`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): Hmm account row; sign-out keeps data; cloudApi switch needs sign-in (#49)`.

### Task 8: One Hmm account per device (link guard)

**Files:**
- Modify: `lib/features/auth/states/login_state.dart`, `lib/features/auth/presentation/screens/login_screen.dart`, the ARB files
- Test: `test/features/auth/login_link_guard_test.dart`

**Interfaces:**
- Consumes: `OwnerIdStore.linkedHmmSub`, `linkedHmmEmail` and `setLink` (Task 1), `switchDataMode` (Task 7).
- Produces: `class OtherHmmAccountException implements Exception { final String linkedAccount; }`.

After a successful `loginWithEmailPassword` (§4.10):
- No link yet → `setLink(user.uid, user.email)` and succeed.
- Link equals `user.uid` → succeed.
- Link differs → `signOut()` (clears the new tokens), leave `currentUserProvider` alone, and throw `OtherHmmAccountException(linkedHmmEmail ?? '—')`.

On that error the login screen shows a dialog (Cupertino on iOS) with `loginOtherAccountTitle`, `loginOtherAccountBody(account)` and two actions:
- **Sign in as that account:** close the dialog, stay on login.
- **Keep data local:** if the mode is `cloudApi`, `switchDataMode(..., DataMode.local)`; then pop `false` if it can pop, else `go('/')`.

ARB keys:

| Key | en | zh |
|---|---|---|
| `loginOtherAccountTitle` | Different Hmm account | 不同的 Hmm 账户 |
| `loginOtherAccountBody` | This device's data belongs to {account}. Sign in as that account, or keep this device's data local. | 本设备的数据属于 {account}。请用该账户登录，或将本设备数据保留在本地。 |
| `loginOtherAccountSignInAs` | Sign in as that account | 用该账户登录 |
| `loginOtherAccountKeepLocal` | Keep data local | 保留在本地 |

- [ ] **Step 1: Write the failing tests:**
  - `first sign-in sets the link`.
  - `same account signs in`.
  - `different account is refused, tokens cleared, link unchanged`.
  - Widget: `dialog shows the linked email; Keep data local in cloudApi switches to local`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run gen-l10n.
- [ ] **Step 4: Run `flutter test test/features/auth`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(auth): a device stays linked to one Hmm account (#49)`.

### Task 9: Settings → Profile (the Me contact)

**Files:**
- Create: `lib/features/settings/presentation/widgets/profile_row.dart`
- Modify: `settings_screen.dart` (top of the list, hidden in `cloudApi` where contacts are unavailable), `lib/core/navigation/contact_routes.dart` (`/contacts/new?self=1`), `lib/features/contacts/presentation/screens/contact_edit_screen.dart` (`selfCard` param), the ARB files
- Test: `test/features/settings/presentation/profile_row_test.dart`

**Interfaces:**
- Consumes: `contactsStateProvider`, `ContactPhoto` (from #96).
- Produces:
  - `ContactEditScreen({String? contactId, bool selfCard = false})`; `selfCard` makes a new contact start with `isSelf: true`.
  - `ProfileRow`. With a Me contact: leading `ContactPhoto(contact, size: 40)`, title the contact's display name, subtitle `settingsProfile`; it opens `/contacts/{id}`. Without one: title `settingsProfileCreate`; it opens `/contacts/new?self=1`.

ARB keys:

| Key | en | zh |
|---|---|---|
| `settingsProfile` | Profile | 个人资料 |
| `settingsProfileCreate` | Create my card | 创建我的名片 |

- [ ] **Step 1: Write the failing tests:**
  - `with a Me contact shows its name and opens it`.
  - `without one shows Create my card and opens the editor with This is me on`.
  - `hidden in cloudApi`.
  - `renaming the Me contact does not change the owner id` (the store's id is unchanged after saving the contact with a new name, §4.7).
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run gen-l10n.
- [ ] **Step 4: Run `flutter test test/features/settings test/features/contacts`, then the full `flutter test` and `flutter analyze`.** Expected: all PASS, analyze clean.
- [ ] **Step 5: Commit** `feat(settings): Profile opens the Me contact (#49)`.
