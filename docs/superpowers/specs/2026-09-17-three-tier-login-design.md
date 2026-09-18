# Login by Tier — Design

**Status:** proposed 2026-09-17. Builds on
`docs/auth-and-service-access-analysis-2026-08-23.md`, which stands as the
analysis; this document is the decision.

**Tracker:** #49 "Login-free local and cloud-storage tiers" (deferred).

## The one-sentence rule

> Sign in to the thing that needs to know who you are — and nothing else.

Three tiers, three identities, and no tier borrows another's:

| Tier | Who must know you | Login | What it unlocks |
|---|---|---|---|
| **On this device** (`local`) | Nobody | **None** | Everything the app does with local data: notes, vehicles, licence, cheatsheets, attachments, on-device OCR, encrypted vault |
| **Sync with OneDrive** (`cloudStorage`) | Microsoft | **OneDrive only** | Backup and cross-device sync of the same local data, through the user's own storage |
| **Hmm Cloud & AI** (`cloudApi`) | Hmm | **Hmm account** | Server-hosted storage, cloud OCR, LLM calls, agents, anything that costs Hmm servers |

Today all three require the Hmm account. The 2026-08-23 analysis names this
as a P0: an IdP outage or an expired token locks the user out of data that
never left the phone. The sync failure fixed in `13f7d31` on 2026-09-17 was
exactly this — cloudStorage sync refused to run because a *Hmm* token had
expired, even though OneDrive was perfectly reachable.

## Reference: how the local-first products do it

The analysis compared five products. The one that matters for the first two
tiers is Obsidian, because its model is the simplest possible:

> "Obsidian stores your notes as Markdown-formatted plain text files in a
> vault. A vault is a folder on your local file system."
> — obsidian.md/help/data-storage

Identity is "whoever can open the folder." There is no account for local use;
an account exists only to pay for Sync or Publish, and even then it
authenticates the *service*, not the app. Notes remain usable offline because
the local vault is authoritative. (The analysis also cites
`help/sync/vault-types` and `help/sync/security`; on 2026-09-17 only
`data-storage` resolved, so only it is quoted here.)

Apple Notes is the same shape with the Apple ID as the implicit owner; Bear and
Joplin likewise. Notion is the counter-example — account mandatory — and it
is mandatory *because* Notion is cloud-first: the app is a client to their
servers. That is the `cloudApi` tier, and only that tier.

**iOS is single-user.** Outside managed Shared iPad, the device *is* the
user. No iPhone app implements multi-user local accounts because the OS has
no such concept. The one-workspace, one-owner rule (user, 2026-09-11) is not a
simplification of the platform; it *is* the platform.

## The single hard problem: what owns a note when nobody signs in

Every local repository filters by `authorId`. Sync scopes OneDrive paths by
the IdP `sub`. Both need an owner. Removing login is not deleting a screen —
it is deciding what supplies that identity when there is no IdP.

**Decision: a local profile with its own stable UUID**, created on first
launch, stored on the device, never derived from an email. This is the
analysis's "Recommended Identity Model" concept #1, and it is the linchpin:

- `local`: the profile UUID **is** the owner. `authorId` maps to it. Nothing
  else is needed.
- `cloudStorage`: OneDrive paths are scoped by the **profile UUID**, not the
  IdP `sub`. This is the change that decouples sync from the Hmm login. Two
  devices sharing one OneDrive must share one profile UUID — which is what
  "restore from OneDrive on a new device" establishes, by reading the UUID
  from the remote manifest.
- `cloudApi`: the profile is **linked** to a Hmm account; the IdP `sub` is
  recorded as an external identity on the profile. The server sees the
  account; the device still sees the profile.

Linking is explicit and one-way-safe: a profile can gain a Hmm account
later without any data moving, because the owner key never changed.

## Why not just skip the login screen

Because the cross-account bug comes first. The analysis's other P0: the sync
repair logic **adopts every note owned by another author** into the current
one. Today that is masked by the single shared login. The moment local
profiles exist, "another author" becomes a real state, and adoption would
silently hand one person's notes to another on a shared device. So:

1. Partition the database, vault, keys, settings and sync state by profile.
2. Remove blanket adoption; scope sync manifests to the active profile.
3. **Then** remove the gate.

Doing 3 before 1–2 is how a data-safety bug ships.

## What each tier looks like to the user

**First launch, any tier:** no login. A profile is created silently. The app
opens on the dashboard. This is the Obsidian experience.

**Turning on "Sync with OneDrive":** a Microsoft sign-in, exactly once. That
is the only credential this tier ever asks for. If the Microsoft token lapses,
the sync dot goes red and the sheet offers **"Reconnect OneDrive"** — the
per-cause first action the 2026-09-17 indicator plan left as out-of-scope
until a real cause showed up. This is it.

**Turning on "Hmm Cloud & AI":** the Hmm account sign-in, with a clear
"link this device's data to your account" step. Everything local keeps
working during an IdP outage; only the cloud features report that sign-in
is needed when connectivity returns. The session states the analysis lists —
`localProfile`, `authenticated`, `offlineAuthenticated`,
`reauthenticationRequired` — are exactly the states the sync indicator now
distinguishes, so the dot and sheet already have somewhere to put them.

**Signing out of Hmm:** stops Hmm services. Asks whether to keep the local
profile on this device (the default) or remove it. It never deletes local
data as a side effect of signing out — that is today's "incomplete sign-out"
P1 inverted into a deliberate choice.

## Login mechanism for the Hmm tier

The IdP already registers an **Authorization Code + PKCE** client
(`hmm.web`, per `Hmm/docs/AUTHENTICATION_GUIDE.md`). The mobile app uses the
password grant (ROPC), which the analysis flags as obsolete and which is the
reason the app holds the user's raw password at all. Switching to PKCE is
therefore a client registration and a Flutter change, not IdP work. It also
gets Apple/Google sign-in for free later, through the IdP, if ever wanted.

Token lifetime is 1 hour. `13f7d31` made the client refresh before declaring
the user signed out; with PKCE the refresh token semantics stay the same.

## Order of work

This is the analysis's phasing, with the sync-indicator work slotted in
where it already fits:

| Phase | Delivers | Blocks |
|---|---|---|
| **0 — Data safety** | Profile partitioning; adoption removed; Alice→sign out→Bob isolation test | everything below |
| **1 — Local-first** | Profile creation on first launch; gate removed from local routes; OneDrive sync scoped by profile UUID; "Reconnect OneDrive" sheet action | — |
| **2 — Modern auth** | PKCE replaces ROPC; central session provider with the listed states; profile↔account linking | — |
| **3 — Hosted AI governance** | Entitlements, consent, agent permissions | Phase 2 |

Phase 0 is the unglamorous one and the one that cannot be skipped. Phase 1
is the user-visible win — the app works with no login. Phase 2 is when the
Hmm login itself gets modernised.

## Out of scope for this document

- Multi-user on one device beyond isolation correctness. iOS does not support
  it and the user has said it is not a goal.
- Which AI features need which entitlement (Phase 3).
- Passkeys / social sign-in — possible through the IdP once PKCE lands, not
  designed here.
