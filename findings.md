# Findings — Cloud-sync improvements

Notes from the investigation that triggered this work. Captured here so I (or a future Claude session after `/clear`) doesn't have to re-derive them.

## 2026-05-24 — Current sync behavior is fully manual

Searched the whole `lib/` tree for any auto-sync mechanism. The ONLY caller of `syncOrchestrator.syncNow()` is:

```
lib/features/settings/presentation/screens/settings_screen.dart:299
  → onPressed: () => _syncNow(context, ref)
```

What is **NOT** present:

- No `Timer.periodic` anywhere.
- No `WidgetsBindingObserver` / `AppLifecycleState` handlers.
- No `workmanager` (Android background) or iOS background-fetch hook.
- No post-write trigger in any repository (create/update/delete returns; sync does not fire).
- No file-watcher on the local SQLite WAL.

User-visible consequence: edits hit local SQLite immediately, but only reach OneDrive when the user explicitly taps **Sync Now**. The SQLite file itself isn't in any OneDrive desktop-sync folder, so the OneDrive desktop client doesn't help either. (Verified earlier in the same session that `Sync Now` does work end-to-end on iOS sim — `[OneDrive] step2=token done` → manifest + note files appear in `/me/drive/special/approot/`.)

## 2026-05-24 — `_useLocal()` covers both `local` AND `cloudStorage`

`lib/core/data/repository_providers.dart:25-26`:

```dart
bool _useLocal(DataMode mode) =>
    mode == DataMode.local || mode == DataMode.cloudStorage;
```

So the `local`-tier repositories (e.g. `LocalGasLogRepository`) are the read/write path for **both** the local and cloudStorage modes. A bug fixed in `LocalGasLogRepository` automatically helps cloudStorage too. The cloudApi mode is the only one that uses the dedicated `ApiSyncProvider` against `Hmm.ServiceApi`.

This matters for Phase A: making `OneDriveGraphClient` aware of the IDP `sub` is enough — the local writes don't change. Only the OneDrive *upload path* needs the user-namespace.

## 2026-05-24 — OneDrive path structure today

From `lib/core/data/sync/onedrive_graph_client.dart` (read this session):

```dart
static const _approot = '/me/drive/special/approot';

// Endpoints:
//   PUT  /me/drive/special/approot:/manifest.json:/content
//   PUT  /me/drive/special/approot:/notes/{id}.json:/content
//   GET  /me/drive/special/approot:/manifest.json:/content
//   GET  /me/drive/special/approot:/notes/{id}.json:/content
//   DELETE /me/drive/special/approot:/notes/{id}.json
```

`/me/drive/special/approot` resolves to the App Folder of the *currently signed-in Microsoft account*. So two **Microsoft-account-different** users wouldn't collide; the issue is two **Hmm-user-different** users on the same Microsoft account — the Hmm `sub` claim is irrelevant to OneDrive routing today.

Per-user fix: insert `users/{sub}/` between `approot` and the existing paths.

## 2026-05-24 — IDP token shape

`AccountController.cs` (Hmm.Idp) issues a JWT after `/connect/token` with the standard `sub` claim — checked in earlier session when debugging the email-confirmation URL. `IdpTokenService.getClaims()` already decodes that JWT and exposes the claims map. So Phase A doesn't need a new IDP endpoint — just call `getClaims()['sub']` from the OneDrive sync provider.

## 2026-05-24 — flutter_appauth → flutter_web_auth_2 migration is already merged

OneDrive sign-in itself works on iOS (sim 18.5 + 26.4) and Android (Pixel 9 Pro emulator). All three phases of this plan build on that working sign-in — no need to re-investigate the auth bridge.

## 2026-05-24 — Manifest is the sync-state source of truth

The orchestrator pushes/pulls `manifest.json` first; that's the file that tracks per-note version + last-known-state. When implementing migration in A.6, **the manifest move is what makes the legacy data "disappear" from the new-path perspective** — if we move only the notes/ files but not the manifest, the new path's manifest will be empty and the orchestrator will think nothing has been synced before. So Migration A.6 must copy `manifest.json` into the per-user subtree too.

(Will verify the exact manifest schema when Phase A starts — already know the high-level shape from the graph_client comments.)

## Open questions to resolve during implementation

- ~~**manifest.json shape**~~ — resolved in A.6: schema in `sync_models.dart` has no "owner" field; the migration just copies the legacy manifest verbatim into the user subtree. No schema bump needed.
- **Connectivity_plus on iOS Simulator** — known to sometimes report "WiFi" even on simulator-without-host-WiFi scenarios. Plan C.9 test must fake the connectivity result rather than rely on the real plugin.
- **Cold-start auth race in B** — `SyncController` must not fire `syncNow()` before `IdpTokenService` has resolved the cached refresh token. Need to read `main.dart` boot order before B.6.

## 2026-05-24 — http_mock_adapter validateStatus gotcha (Phase A)

Discovered while writing `onedrive_graph_client_path_test.dart`. The production `OneDriveGraphClient` constructs its default Dio with `validateStatus: (_) => true` so its production code can do `if (resp.statusCode == 404) return null` cleanly. When a test passes its **own** `Dio()` instance to the client (to hook `http_mock_adapter` to it), that override is gone — and every "missing file returns null" test fails with a misleading `DioException [bad response]` instead of returning the mocked 404 Response.

**Fix in test setUp:**
```dart
dio = Dio(BaseOptions(validateStatus: (_) => true));
adapter = DioAdapter(dio: dio);
```

Will hit the same trap when writing Phase B's `sync_controller_test.dart` if it instantiates a real graph client. Heads-up captured here so the next session doesn't lose time on it.

## 2026-05-24 — `_approot` segment-joining subtlety (Phase A)

Microsoft Graph's "address an item under a special folder" syntax is:
`/me/drive/special/approot:/{relative-path}[:/content]`

The colon `:` is the boundary marker between the special-folder selector and the relative path. When nesting under `users/{sub}/...`, the path becomes:
`/me/drive/special/approot:/users/{sub}/{rest}[:/content]`

Only ONE colon at the boundary, then `/users/...` as part of the relative path. Got this wrong on the first sketch (tried `approot:/users/{sub}:/notes/{id}.json:/content` — two colons — which Graph interprets as a "drive-relative item path" rather than an approot-relative one).
