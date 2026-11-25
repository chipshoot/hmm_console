# Login-free local and cloud-storage tiers (#49) — 2026-11-24 update

Status: **approved by owner 2026-11-25**. Depends on #96 Contact photo.

**Builds on** `2026-09-17-three-tier-login-design.md` (the "Login by Tier"
design, proposed, never built). That document's rule, tier table, reference
products and PKCE plan still stand. This update records the owner's
2026-11-24 decisions and changes the parts listed in §0.

## 0. What changes from the 2026-09-17 design

| Topic | 2026-09-17 said | Now |
|---|---|---|
| Owner key | a new local profile UUID for everyone | new installs: a new UUID; **existing installs keep their current id (the IdP `sub`)** so no note changes owner and the OneDrive folder doesn't move |
| Phase 0 (partition DB/vault/settings by profile, remove sync adoption) | must come first | **dropped (owner, 2026-11-24).** The owner id is fixed per device and never follows a login, so a second local owner can't appear; one workspace, one owner (owner, 2026-09-11). The one remaining cross-account case is guarded in §4.10 |
| Profile | an internal record | the **"Me" contact** is the visible profile (D3) |
| First launch | silent profile, straight to dashboard | onboarding picks the tier first (§4.1) |
| Server features in local/OneDrive | not covered | ask to sign in when used (D5) |
| Hmm sign-out | asks keep/remove profile | removes only the Hmm token; data stays (§4.6) |
| PKCE (Phase 2) | — | unchanged, still later, not part of this work |

## 1. Intent

In `local` and `cloudStorage` modes Hmm opens straight to my data, with no
login or register screen. Only `cloudApi` keeps the Hmm login, because there
the server must know who is calling.

Why (from #49, 2026-09-11, and the 2026-09-17 design): one workspace and one
owner per device; local-first peers have no login; today an outage of the Hmm
IdP locks me out of data already on my phone.

## 2. How it works today (findings, 2026-11-24)

- **The gate.** `router_config.dart` sends anyone not signed in to `/auth`.
  The first-run screen (`onboarding_screen.dart`: "new user" → stays `local`,
  "migrating" → `cloudStorage` + OneDrive sign-in + pull) runs only after
  login (`onboarding_redirect.dart` returns null when not authenticated).
- **Author on every note.** `currentAuthorAccountNameProvider` returns the
  signed-in user's IdP `sub` and throws if none; `currentAuthorProvider`
  get-or-creates the local `Authors` row (`accountName` unique). Readers:
  `local_hmm_note_repository.dart`, `sync_orchestrator.dart`,
  `linked_dates_sync.dart`, `dashboard_screen.dart`,
  `automobile_edit_screen.dart`, plus the auth files.
- **No author is shown anywhere** in the UI.
- **OneDrive sync carries no author**; a pulled note is stamped with the
  local author. `cloudApi` resolves its own author from `/v1/authors`.
- **OneDrive data is filed under the IdP `sub`:** `approot/users/{sub}/`
  (`onedrive_graph_client.dart`), plus one legacy-migration marker at
  `approot/users/.legacy_migrated.json`.
- **Server features used outside `cloudApi`:** Cloud AI receipt scan
  (`api_llm_extractor.dart`), address lookup
  (`geocoding_remote_datasource.dart`), exchange rates
  (`exchange_rate_remote_datasource.dart`); they need a Hmm token.
- **Sign-out** of Hmm is on the dashboard (`signout_usecase.dart`) and lands
  on `/auth`; OneDrive has its own sign-out in Settings.

## 3. Decisions (owner, 2026-11-24)

| # | Decision |
|---|---|
| D1 | No login in `local` and `cloudStorage`; login only for `cloudApi`. |
| D2 | No author setup screen. A hidden **owner id** is created automatically and **never changes**. Existing installs keep their current id. |
| D3 | The visible **profile is the existing "Me" contact** (`isSelf`), opened from Settings → Profile. No separate profile store. |
| D4 | Contacts get an optional iOS-style photo (#96, built first); the Me contact's photo is the profile picture. |
| D5 | Server features **ask to sign in when used** (option A); the sign-in is remembered. Not hidden; the server is not opened to anonymous callers. |

## 4. Design

### 4.1 First launch (new install)

```
Welcome to Hmm
  ○ On this device only        → home, no account             (local)
  ○ Sync with my OneDrive      → OneDrive sign-in, pull, home (cloudStorage)
  ○ Hmm cloud (server)         → Hmm login / register, home   (cloudApi)
```

Onboarding becomes the front door instead of the login screen and gains the
third option. "Skip" keeps today's meaning (stay `local`).

### 4.2 The gate

- A Hmm sign-in is required **only when the mode is `cloudApi`**. In
  `local`/`cloudStorage` the router never redirects to `/auth`; the
  onboarding gate no longer waits for "authenticated".
- `/auth` stays reachable from onboarding's Hmm cloud option, from switching
  to `cloudApi`, and from a server feature's sign-in prompt.
- In `cloudApi`, an expired or failed sign-in still goes to `/auth`.

### 4.3 Owner id (my calls inside D2)

- `ownerIdProvider` replaces `currentAuthorAccountNameProvider` for local
  data; stored in prefs, created once, never rewritten.
- **Existing install, first launch of the new build:** if no owner id is
  stored, use the signed-in user's `sub`; if signed out, the `sub` in token
  storage; failing that, the `accountName` of the single `Authors` row if
  exactly one exists; only then a new UUID.
- `currentAuthorProvider` keys off the owner id; the readers in §2 switch to
  it. The `Authors` table doesn't change.
- `cloudApi` keeps using the server's author for pushes.

### 4.4 Finding OneDrive data without a Hmm login (my calls)

The folder layout `approot/users/{id}/` stays; how a device picks `{id}`
changes:

1. This device's owner id has a folder → use it (existing installs).
2. Otherwise list `approot/users/`:
   - exactly one folder and **no notes on this device yet** (no non-deleted
     note in the local database, any author) → adopt its name as this
     device's owner id, silently;
   - exactly one folder but this device already has notes → ask (the same
     Settings chooser as below, listing that one folder); choosing it adopts;
   - none → create one with this device's owner id;
   - several (unlikely) → ask which to use.

Adoption happens before the first pull, so a new iPad joins the iPhone's
data. (The 2026-09-17 design read the id from the remote manifest; listing
the folder works the same and needs no manifest change.)

**Owner decisions, 2026-11-25:**

- **D-A. Silent join only on an empty device.** A device that already holds
  notes never joins a foreign folder on its own: its notes would move onto
  that folder's owner. The person decides in Settings.
- **D-B. Joining clears the account link.** Any adoption (automatic, chosen
  in Settings, or onto an existing `Authors` row of that name) clears
  `linkedHmmSub` and `linkedHmmEmail`, so the next Hmm sign-in sets the link
  afresh (§4.10).

Adopting renames the owner's `Authors` row to the folder name (exact case)
so every note keeps its author id; the row is renamed first and the rename
undone if storing the owner id fails, so the two never disagree. A folder
lookup that fails for any other reason stops the sync before orphan-note
adoption runs.

### 4.5 Server features (D5)

- One shared "needs Hmm sign-in" check in front of the three features.
  Signed out → a sheet: "Sign in to Hmm to use <feature>" with Sign in /
  Cancel. Sign in opens `/auth` and returns to where you were.
- The token is stored as now; no further prompts until it expires.
- Settings shows "Hmm account: signed in as … / Sign in" in every mode.

### 4.6 Sign-out (my call)

- In `local`/`cloudStorage`, Hmm sign-out only removes the Hmm token;
  server features ask again. Data stays open, no redirect. The dashboard
  Sign out entry moves to Settings → Hmm account.
- In `cloudApi`, sign-out works as today.

### 4.7 Profile (D3)

- Settings → Profile opens the Me contact; if none, "Create my card" opens a
  new contact with "This is me" set.
- Renaming or deleting the Me contact never touches the owner id.
- Nothing else shows the profile in this change (a home greeting can come later).

### 4.8 Switching modes

- To `cloudApi`: needs a Hmm sign-in then (cancel = stay in current mode).
- From `cloudApi` to `local`/`cloudStorage`: no sign-in needed.

### 4.10 Linking the device owner to a Hmm account (switching to `cloudApi`)

The owner id never goes to the server, and it never needs to. The two sides
are joined by a link record on the device, not by sharing an id (the
2026-09-17 design's "external identity on the profile"):

- **Server side (unchanged):** the server knows you only by your Hmm
  account. On the first call after register/login it creates your author
  from the JWT `sub` (`CurrentUserAuthorProvider.CreateUserAuthor`); the
  account name you typed is the server's business.
- **Device side (new):** when you first sign in to Hmm, the device saves
  `linkedHmmSub = <sub>` next to the owner id. That is the whole link.
- **Pushing:** every note sent to the server carries the *server's* author
  id for the signed-in account (`ApiSyncProvider._resolveAuthorId`, as
  today). The local owner id is never sent.
- **Pulling:** notes from the server are stored locally under the local
  owner id, the same way OneDrive pulls work today.
- **Guard (replaces Phase 0):** if a *different* Hmm account signs in on a
  device that is already linked, Hmm stops before syncing and asks:
  "This device's data belongs to <linked account>. Sign in as that account,
  or keep this device's data local." It never merges two accounts' data
  under one owner.
- **Existing installs:** when the owner id comes from a token `sub` (the
  signed-in user's, or the stored, possibly expired, token's),
  `linkedHmmSub` is set to it at upgrade. An owner id taken from an
  `Authors` row or a new UUID sets no link: an `accountName` (`local-user`,
  an adopted folder name) is not a `sub`, and linking it would refuse every
  real sign-in. If the stored token cannot be read or decoded, nothing is
  stored and resolution is retried later.
- **Joining a OneDrive folder clears the link** (owner decision D-B,
  2026-11-25, §4.4); the next Hmm sign-in sets it fresh.
- **Signing in only for server features** (D5, while staying in
  `local`/`cloudStorage`) also sets the link, so the guard applies there too.

**Note:** `cloudApi` itself is only partly built today:
`hmmNoteRepositoryProvider` throws "API note repository not yet implemented"
in `cloudApi`, and the Settings mode switch changes mode without moving any
data. Uploading a device's existing local data when it first links to an
account belongs to the work that finishes `cloudApi`, not to #49. #49 only
records the link and enforces the guard.

### 4.9 Current users after the update

The login screen stops appearing in `local`/`cloudStorage`. Owner id =
current `sub`; OneDrive folder unchanged; no data migration.

## 5. Goals, non-goals, anti-goals

- **Goals:** open on-device data with no account; IdP outages never block
  `local`/`cloudStorage`; a new device finds its OneDrive data with only a
  OneDrive sign-in.
- **Non-goals:** multi-user on one device; anonymous server access; a profile
  store separate from the Me contact; changing `cloudApi` auth (PKCE stays
  a later phase per the 2026-09-17 design).
- **Anti-goals:** any note changing owner; a new device creating a second
  OneDrive folder and splitting data; server features silently vanishing.

## 6. Approaches

1. **Mode-aware gate + fixed owner id** (chosen — the one sensible way):
   login required only for `cloudApi`; "signed-in user" replaced by "device
   owner" in the ~8 readers.
2. **"Skip login" / guest button**: cheapest, but keeps the login screen as
   the front door, which #49 removes. Rejected.
3. **Silent anonymous server accounts**: keeps code paths the same but still
   fails when the IdP is down, the problem #49 fixes. Rejected.

## 7. Risks to test

- Upgrade with no token (signed out earlier) must still find the old owner id (§4.3 fallbacks).
- OneDrive folder adoption racing a first local write on a new device.
- `linked_dates_sync` and the sync orchestrator reading the owner before
  onboarding finishes.
- Many tests fake a login via `currentUserProvider`; they move to an owner-id override.

## 8. Open questions for the owner

None open. (Q1, drop Phase 0: yes, owner 2026-11-24.)

## 9. Left to the builder

Exact copy, the sign-in sheet's look, where the Hmm account row sits in
Settings, prefs key names, and help entries for changed screens.
