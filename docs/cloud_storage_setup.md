# Cloud Storage Provider Setup

Setup instructions for each cloud storage provider the Hmm Console app can sync to. OneDrive is the **v1 provider**; others are documented here as reference for future implementation.

Related design: `docs/task_plan.md`, `docs/findings.md`.

---

## Provider Status

| Provider | Platforms | Status | Flutter SDK |
|----------|-----------|--------|-------------|
| **OneDrive** (Microsoft Graph) | iOS, Android, macOS, Windows, Web | v1 — active | `flutter_appauth` + raw Graph REST |
| iCloud | iOS, macOS only | Deferred | `icloud_storage` (community) |
| Google Drive | iOS, Android, Web, desktop | Deferred | `google_sign_in` + `googleapis` |
| Dropbox | iOS, Android, Web, desktop | Deferred | `flutter_appauth` + REST |

---

## 1. OneDrive (Microsoft Graph) — **v1**

### 1.1 Register the app in Microsoft Entra ID (formerly Azure AD)

1. Go to <https://entra.microsoft.com> → sign in with any Microsoft account.
2. Navigate: **Applications → App registrations → New registration**.
3. Fill in:
   - **Name:** `Hmm Console` (user-facing — shown on consent screen)
   - **Supported account types:** *Accounts in any organizational directory and personal Microsoft accounts (multi-tenant + personal)*. This is required so consumer OneDrive works.
   - **Redirect URI:** leave blank for now; add per-platform below.
4. Click **Register**. Copy the **Application (client) ID** from the Overview page — you'll paste it into the app config.

### 1.2 Configure redirect URIs (Authentication blade)

Add one platform at a time:

| Platform | Platform type | Redirect URI |
|----------|---------------|--------------|
| iOS / macOS | Mobile and desktop applications | `com.homemademessage.hmm://auth` |
| Android     | Mobile and desktop applications | `com.homemademessage.hmm://auth` |
| Windows     | Mobile and desktop applications | `http://localhost` |
| Web         | Single-page application (SPA)   | `https://homemademessage.com/oauth/callback` (or `http://localhost:3000/auth` for dev) |

Under **Advanced settings** on the Authentication blade:
- Set **Allow public client flows** → **Yes** (required for PKCE/native apps — no client secret).

### 1.3 Configure API permissions

1. **API permissions → Add a permission → Microsoft Graph → Delegated permissions**.
2. Add these scopes:
   - `Files.ReadWrite.AppFolder` — sandboxed per-app folder in user's OneDrive
   - `User.Read` — basic profile (for showing "signed in as ..." in settings)
   - `offline_access` — required to receive refresh tokens
3. Click **Grant admin consent** only if you own a tenant. For consumer OneDrive, the user grants consent at first sign-in.

### 1.4 App config values

Copy these into `lib/core/data/sync/onedrive_auth.dart` (or an env/config file):

```dart
const onedriveClientId   = '<Application (client) ID from step 1.1>';
const onedriveAuthority  = 'https://login.microsoftonline.com/common';
const onedriveRedirectUri = 'com.homemademessage.hmm://auth';
const onedriveScopes = [
  'Files.ReadWrite.AppFolder',
  'User.Read',
  'offline_access',
];
```

### 1.5 Platform-specific native config

**iOS** (`ios/Runner/Info.plist`): register the custom URL scheme so the OAuth redirect reaches the app.

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.homemademessage.hmm</string>
    </array>
  </dict>
</array>
```

**Android** (`android/app/build.gradle.kts`): expose the scheme to `flutter_appauth`.

```kotlin
android {
    defaultConfig {
        manifestPlaceholders["appAuthRedirectScheme"] = "com.homemademessage.hmm"
    }
}
```

**macOS** (`macos/Runner/Info.plist`): same as iOS.

**Web:** add a redirect handler page at the configured URI.

### 1.6 Storage layout

Under the app folder (`/drive/special/approot`):

```
/notes/<note-id>.json          # each note as a JSON blob
/attachments/<attach-id>.<ext> # binary files (photos, docs)
/manifest.json                 # index with { id, type, updated_at, deleted } per record
```

Graph endpoints used:
- `GET /me/drive/special/approot:/manifest.json:/content` — pull manifest
- `PUT /me/drive/special/approot:/notes/<id>.json:/content` — push note
- `PUT /me/drive/special/approot:/attachments/<id>.<ext>:/content` — push attachment

### 1.7 Testing checklist

- [ ] Sign in with personal `outlook.com` account → tokens returned
- [ ] Sign in with work/school account → tokens returned (multi-tenant verified)
- [ ] App folder auto-created on first write
- [ ] Refresh token survives 1h access-token expiry
- [ ] Sign-out clears local tokens

---

## 2. iCloud (deferred)

iCloud works only on iOS and macOS, so it cannot be the sole CloudStorage provider in a cross-platform app. Documented here for when it's added as a secondary provider.

### 2.1 Requirements
- Apple Developer Program membership ($99/yr) — free accounts cannot enable iCloud entitlements.
- Xcode 15+.

### 2.2 Two integration surfaces

| Surface | Shape | Use case |
|---------|-------|----------|
| **iCloud Documents (Ubiquity Container)** | File-level sync | Drop-in file store — fits our note-blob + attachment layout |
| **CloudKit** | Record + field sync with queries | Richer but more work; server-side schema |

**Recommendation for Hmm Console:** iCloud Documents. We already have a JSON-blob layout that maps directly.

### 2.3 Setup steps (iCloud Documents)
1. Apple Developer portal → **Identifiers → App IDs** → enable **iCloud** capability.
2. Create an **iCloud Container:** `iCloud.com.homemademessage.hmm`.
3. Xcode → Target → **Signing & Capabilities → + Capability → iCloud**:
   - Check **iCloud Documents**.
   - Select the container created above.
4. Add provisioning profile with iCloud entitlement.
5. Flutter package: `icloud_storage` (pub.dev). Community-maintained; test thoroughly.

### 2.4 File layout
Mirror the OneDrive layout in the container's Documents directory:
```
Documents/notes/<id>.json
Documents/attachments/<id>.<ext>
Documents/manifest.json
```

### 2.5 Caveats
- No Android / Windows / Web support — if user switches device OS, data doesn't follow.
- iCloud conflicts surface as duplicate files with the remote device name — sync engine must detect and resolve.

---

## 3. Google Drive (deferred)

### 3.1 Requirements
- Google Cloud project (free tier is fine).
- OAuth consent screen published (goes through verification if broad scopes are requested — we only need the sandboxed `drive.appdata` scope, which is auto-approved).

### 3.2 Setup
1. <https://console.cloud.google.com> → Create project `hmm-console` (or reuse).
2. **APIs & Services → Enable APIs → Google Drive API**.
3. **OAuth consent screen:**
   - User type: **External**
   - App name: `Hmm Console`
   - Scopes: `.../auth/drive.appdata` (sandboxed per-app folder)
   - Publishing status: **In production** (no verification needed for `drive.appdata`)
4. **Credentials → Create OAuth client ID** — one per platform:
   - iOS: Bundle ID `com.homemademessage.hmm` → receive reversed client ID URL scheme
   - Android: Package `com.homemademessage.hmm` + SHA-1 from `keytool`
   - Web: Redirect URI `https://homemademessage.com/oauth/callback`

### 3.3 Scopes
- `https://www.googleapis.com/auth/drive.appdata` — app-specific hidden folder. User cannot browse it in Drive UI; perfect for app state.

### 3.4 Flutter packages
- `google_sign_in` for OAuth on mobile
- `googleapis` for Drive REST calls
- Or: `flutter_appauth` + raw Drive REST (consistent with OneDrive)

### 3.5 File layout
Same structure as OneDrive, inside the appDataFolder:
```
notes/<id>.json
attachments/<id>.<ext>
manifest.json
```
Query with `parents in 'appDataFolder' and name = '<filename>'`.

---

## 4. Dropbox (deferred)

### 4.1 Setup
1. <https://www.dropbox.com/developers> → **App Console → Create app**.
2. Choose **Scoped access** + **App folder** (sandboxed).
3. App name: `Hmm Console`.
4. **Permissions tab** → enable:
   - `files.content.write`
   - `files.content.read`
   - `account_info.read`
5. **Settings tab → OAuth 2 → Redirect URIs**, add one per platform (custom scheme `com.homemademessage.hmm://auth` works).
6. Copy **App key** (no secret — use PKCE).

### 4.2 Flutter packages
- `flutter_appauth` for OAuth/PKCE against `https://www.dropbox.com/oauth2/authorize`
- Raw REST via `dio` / `http` for Dropbox Files API

### 4.3 File layout
Inside `/Apps/Hmm Console/`:
```
/notes/<id>.json
/attachments/<id>.<ext>
/manifest.json
```

---

## Cross-Provider Notes

### Token storage
All providers that issue OAuth tokens (OneDrive, Drive, Dropbox) store tokens in `flutter_secure_storage`:
- Key per provider: `cloud_token:onedrive`, `cloud_token:gdrive`, `cloud_token:dropbox`.
- Contents: JSON `{accessToken, refreshToken, expiresAt, accountId}`.
- iCloud uses device identity → no token; sign-in = system iCloud setting.

### Scope minimisation
Prefer **app-folder scoped** permissions over full-drive access:
- OneDrive: `Files.ReadWrite.AppFolder`
- Google Drive: `drive.appdata`
- Dropbox: App folder access

This reduces consent-screen friction and means a compromised token can't read the user's other files.

### Redirect URI hygiene
Use a **single custom scheme** — `com.homemademessage.hmm` — across providers and platforms where possible. Distinguish by path: `/auth/onedrive`, `/auth/gdrive`, etc.
