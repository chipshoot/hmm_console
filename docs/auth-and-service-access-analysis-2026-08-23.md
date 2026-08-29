# Authentication and Service Access Analysis

**Date:** 2026-08-23  
**Status:** Architecture recommendation  
**Scope:** Local note access, Hmm accounts, cloud services, AI features, user
identity, and data ownership

## Executive Summary

Hmm should support a complete local note-management experience without
registration. A Hmm account should become necessary when a user enables a
service that consumes Hmm-hosted resources or requires a server identity, such
as Cloud API storage, cloud OCR, LLM calls, AI agents, collaboration, quotas, or
billing.

The governing principle is:

> Local features require a local profile. Functions that consume Hmm web-service
> resources require a Hmm account.

This model fits Hmm's existing local-first data modes while retaining accounts
where they provide real value: server authorization, synchronization, recovery,
abuse prevention, entitlements, and collaboration.

Before introducing account switching, the current cross-account data ownership
behavior must be corrected. The shared local database and sync adoption logic
can otherwise transfer one user's notes to another user on the same device.

## Product Comparison

### Obsidian

- Local vaults work without an Obsidian account.
- An account is used for Obsidian Sync and other hosted services.
- Notes remain usable offline because the local vault is authoritative.
- Obsidian Sync can use a separate end-to-end encryption password.

References:

- <https://obsidian.md/help/data-storage>
- <https://obsidian.md/help/sync/vault-types>
- <https://obsidian.md/help/sync/security>

### Apple Notes

- Notes uses device and system accounts rather than requiring a separate Notes
  registration.
- An `On My iPhone` account stores notes locally.
- iCloud, Exchange, Google, and other accounts can be added for synchronization.
- Locked notes can use the device passcode, Face ID, Touch ID, or a separate
  Notes password.

References:

- <https://support.apple.com/en-ae/guide/iphone/iph7262fd4fe/ios>
- <https://support.apple.com/en-ca/guide/security/sec1782bcab1/web>

### Evernote

- Evernote is account-centric because its primary model is hosted sync.
- Previously downloaded content can remain available offline, subject to mobile
  caching and plan behavior.
- It supports federated login, two-step verification, backup codes, and remote
  device revocation.

References:

- <https://help.evernote.com/hc/en-us/articles/209005917-Access-notes-offline>
- <https://help.evernote.com/hc/en-us/articles/208314238-Set-up-two-step-verification>
- <https://help.evernote.com/hc/en-us/articles/208313878-Revoke-access-to-your-Evernote-account>

### Notion

- Notion is cloud-account-centric.
- Login options include email verification codes, passwords, Google, Apple,
  Microsoft, SSO, and passkeys.
- It supports MFA, recovery codes, login alerts, and remote session logout.
- Selected pages can be downloaded for offline work, but the cloud workspace is
  still the main ownership model.

References:

- <https://www.notion.com/en-gb/help/log-in-and-out>
- <https://www.notion.com/help/two-step-verification>
- <https://www.notion.com/en-gb/help/use-pages-offline>

### Microsoft OneNote

- OneNote uses Microsoft personal, work, or school accounts.
- Multiple accounts and notebooks are supported.
- Cached notebooks can be edited offline and synchronized when connectivity
  returns.
- Sections can be protected with separate passwords.

References:

- <https://support.microsoft.com/en-us/onenote/use-multiple-microsoft-accounts-with-onenote-for-windows-10>
- <https://support.microsoft.com/en-us/onenote/work-offline-in-microsoft-onenote-for-ipad-or-iphone>
- <https://support.microsoft.com/en-US/OneNote/onenote-help-and-learning/protect-your-notes-with-a-password>

### Implication for Hmm

Obsidian and Apple Notes are the most appropriate references for Hmm's local
mode. Evernote, Notion, and OneNote demonstrate the account security and session
management expected once hosted services are enabled.

## Current Hmm Architecture

According to `CLAUDE.md`, Hmm supports three data modes:

- `local`: Drift/SQLite only.
- `cloudStorage`: local Drift data synchronized through a personal provider such
  as OneDrive.
- `cloudApi`: repositories backed by Hmm's web API.

Authentication currently uses the self-hosted Hmm OpenID Connect provider.
Email and password are submitted through the OAuth Resource Owner Password
Credentials grant. Access and refresh tokens are stored with
`flutter_secure_storage`.

Despite having a local mode, the router redirects every unauthenticated user to
`/auth`. As a result, local notes are gated by the availability and lifetime of
the Hmm identity session.

## Current Risks

### P0 — Cross-account data ownership

The app uses one database path:

- `lib/core/data/data_mode.dart:53-57`

Normal note queries correctly filter by the active author, but the sync repair
logic reassigns every note owned by another author to the current author:

- `lib/core/data/sync/sync_orchestrator.dart:471-487`

That logic assumes an installation has one usable author. If Alice signs out
and Bob signs in, Bob's sync can adopt Alice's notes and potentially upload them
under Bob's account.

Required correction:

- Namespace databases, attachment roots, settings, vault-key aliases, and sync
  metadata by a stable local profile ID.
- Scope every sync manifest and query to the active owner.
- Remove blanket adoption of notes belonging to another author.
- Add an Alice -> sign out -> Bob integration test covering notes, attachments,
  settings, and outgoing sync data.

Account switching should not be offered until this is fixed.

### P0 — Local mode requires authentication

The router's authentication redirect is located at:

- `lib/core/navigation/router_config.dart:47-55`

The default mode is local:

- `lib/core/data/data_mode.dart:25-31`

An IdP outage, expired access token, or fresh offline installation can therefore
prevent access to data stored entirely on the device. This contradicts the
local-first design.

### P0 — Split session initialization

The router decides authentication using token validity:

- `lib/features/auth/data/data/auth_data_source.dart:60-64`

The in-memory user initially contains no identity:

- `lib/features/auth/providers/current_user_provider.dart:4-16`

Claims are restored later from the dashboard:

- `lib/features/dashboard/presentation/screens/dashboard_screen.dart:24-44`

Data providers require a current user and throw if it is missing:

- `lib/core/auth/current_author_account_name_provider.dart:15-24`

Deep links, onboarding, or background work may therefore reach account-scoped
data before dashboard restoration completes.

### P0 — Incomplete sign-out

Sign-out currently clears Hmm tokens and emits an unauthenticated event:

- `lib/features/auth/data/data/auth_data_source.dart:54-58`
- `lib/core/network/token_storage.dart:45-50`

It does not centrally guarantee that the application also:

- Stops synchronization.
- Clears the in-memory identity.
- Locks and clears cached vault keys.
- Invalidates account-scoped repositories.
- Switches or closes the active profile database.
- Disconnects account-scoped cloud storage where appropriate.
- Offers to retain or remove the local profile from the device.

### P1 — Obsolete OAuth password flow

The mobile client collects the user's IdP password and uses the password grant:

- `lib/core/network/idp_token_service.dart:22-39`

OAuth Security Best Current Practice states that this grant must not be used.
It increases credential exposure and does not support MFA, passkeys, federation,
or other multi-step authentication cleanly.

Reference:

- <https://datatracker.ietf.org/doc/rfc9700/>

The replacement should be OpenID Connect Authorization Code with PKCE through
the system browser. The mobile app should be registered as a public client and
should not rely on a client secret embedded in the application.

### P1 — Token lifecycle

Startup authentication checks only access-token validity. It does not first
attempt to use a valid stored refresh token:

- `lib/core/network/token_storage.dart:36-43`
- `lib/features/auth/data/data/auth_data_source.dart:60-64`

An expired access token can therefore appear as a complete logout even if the
refresh token remains usable. Concurrent refreshes also need a single-flight
mechanism to avoid refresh-token rotation races.

### P1 — Recovery and account management

Password reset is currently a static placeholder:

- `lib/features/auth/presentation/screens/forgot_password_screen.dart:18-29`

A complete hosted account offering should provide:

- Password or passkey recovery.
- Email verification status and resend feedback.
- MFA and recovery codes.
- Authorized-device/session management.
- Remote logout.
- Account deletion and data export.
- Email/login-method management.

### P1/P2 — Privacy and encryption

Ordinary note content is stored in the local SQLite database without
application-level database encryption. Sensitive attachment encryption exists,
but it does not encrypt all note text, structured records, or every cloud mode.

The product must describe this accurately. Future work should consider OS file
protection, database encryption with a key held by the platform keystore, an
optional app lock, and a clear decision about end-to-end encryption for hosted
content.

## Recommended Identity Model

Five concepts should remain separate:

1. **Local profile** — owns data on this device and works offline.
2. **Hmm account** — authorizes access to Hmm web services.
3. **Cloud-provider identity** — authorizes OneDrive or another personal storage
   provider.
4. **App lock** — protects local access using biometrics or a device passcode.
5. **Subscription and entitlements** — determine service quotas and premium
   capabilities.

The local profile should have its own stable UUID. When linked to a Hmm account,
the profile records the IdP `sub` as an external identity. Email must not be the
permanent owner key because it can change.

## Feature and Account Tiers

Features should be grouped by their execution and data boundary, not by whether
they are described as basic or advanced.

| Tier | Account requirement | Example functions |
|---|---|---|
| Local | No account | Create/edit/search notes, catalogs, tags, attachments, cheatsheets, vehicle records, local export/import, on-device OCR |
| Personal cloud | Provider account only | OneDrive synchronization and backup when the Hmm backend does not participate |
| Hmm services | Hmm account | Cloud API storage, cloud AI OCR, LLM calls, AI agents, server-side indexing and Hmm synchronization |
| Collaboration | Hmm account | Sharing, invitations, shared catalogs, comments and access control |
| Paid or managed AI | Hmm account plus entitlement | Usage quotas, premium models, larger contexts, scheduled agents and automation |

On-device OCR should not require registration because it does not consume Hmm
servers. Cloud OCR should require an account.

In user-facing copy, prefer concrete labels such as:

- `On this device`
- `Sync with OneDrive`
- `Hmm Cloud & AI`

Avoid presenting the split as `Basic` versus `Advanced`; the local product
should still feel like a complete note manager.

## Recommended Onboarding

```text
Welcome
|-- Continue on this device
|   `-- Create a local profile immediately
`-- Sign in or create account
    `-- Enable Hmm Cloud and online services
```

When a local user later creates or links an account:

```text
Local profile
  -> Sign in or sign up
  -> Confirm the destination account
  -> Review data that will upload
  -> Resolve merge or duplicate choices
  -> Link the profile
  -> Begin synchronization
```

The application must never silently merge a local profile into an existing
cloud account. Before linking, show:

- The local profile being linked.
- The destination account.
- Note and attachment counts.
- Existing cloud data and possible conflicts.
- The upload and encryption implications.
- An export or backup option before migration.

## Capability-Based Access

Authentication checks should not be scattered throughout widgets. Introduce a
central capability service or Riverpod provider.

Example capabilities:

```dart
enum AppCapability {
  localNotes,
  localSearch,
  onDeviceOcr,
  oneDriveSync,
  hmmCloudSync,
  cloudOcr,
  llmAssistant,
  aiAgents,
  collaboration,
}
```

Availability should explain why access is unavailable:

```dart
sealed class CapabilityAvailability {
  const CapabilityAvailability();
}

class Available extends CapabilityAvailability {
  const Available();
}

class RequiresAccount extends CapabilityAvailability {
  const RequiresAccount();
}

class RequiresConnection extends CapabilityAvailability {
  const RequiresConnection();
}

class RequiresConsent extends CapabilityAvailability {
  const RequiresConsent();
}

class QuotaExceeded extends CapabilityAvailability {
  const QuotaExceeded();
}

class RequiresUpgrade extends CapabilityAvailability {
  const RequiresUpgrade();
}
```

This enables precise UI messages such as:

- `Sign in to use Cloud AI.`
- `Connect to the internet to run this agent.`
- `Review how this note will be processed.`
- `You have used this month's AI allowance.`

## Account Information to Retain

Keep the Hmm account profile deliberately small:

- Stable opaque account ID (`sub`).
- Verified email addresses and login methods.
- Display name and locale.
- Subscription and entitlements.
- AI usage and quota state.
- Consent versions and timestamps.
- Authorized sessions and devices.
- Server-side data ownership identifiers.

Local-only preferences and note content should not be uploaded merely because a
user created an account. Upload should follow the selected service and explicit
consent.

## AI, OCR, and Agent Requirements

Before sending note content to a cloud OCR, LLM, or agent service:

- Identify that processing occurs in the cloud.
- Explain which text and attachments will be sent.
- Obtain explicit consent before first use.
- Send only the minimum content required for the operation.
- Exclude sensitive attachments by default.
- Publish retention and model-training policies.
- Allow deletion of AI history and server-side artifacts.
- Enforce quotas and abuse prevention on the server, not only in Flutter.
- Require recent reauthentication for sensitive autonomous operations.

Agent permissions should be granular:

- Read the current note.
- Search selected catalogs.
- Propose modifications.
- Create notes.
- Share, publish, or send externally.

Default agents to read-only or proposal mode. Require explicit confirmation for
deletion, external sharing, sending messages, bulk changes, and other difficult
to reverse actions.

## Target Session Model

A central asynchronous session provider should restore tokens, refresh when
possible, hydrate identity, select the correct local profile, and expose explicit
states before routing or account-scoped data access begins.

Suggested states:

- `initializing`
- `localProfile`
- `authenticated`
- `offlineAuthenticated`
- `reauthenticationRequired`
- `signedOut`

Expected behavior:

- A local profile may enter all local routes without an IdP session.
- An authenticated profile may additionally use entitled cloud functions.
- If a token expires while offline, local features continue working and cloud
  features show that sign-in is required when connectivity returns.
- Signing out stops Hmm services but asks whether the local profile should be
  retained or removed from the device.
- App lock and biometric unlock remain independent of cloud sign-in.

## Delivery Priorities

### Phase 0 — Data safety

1. Partition databases, vaults, keys, settings, and sync state by local profile.
2. Remove cross-author adoption and scope sync manifests to the active owner.
3. Add multi-user isolation tests.
4. Implement coordinated sign-out and profile switching.

### Phase 1 — Local-first access

1. Add local profile creation.
2. Remove the global authentication gate from local routes.
3. Add capability checks around hosted features.
4. Provide a deliberate local-profile-to-account linking flow.

### Phase 2 — Modern authentication

1. Replace the password grant with Authorization Code plus PKCE.
2. Centralize session restoration and refresh.
3. Implement verification, reset, MFA, recovery, and session management.
4. Add Apple, Google, or passkeys through the IdP when justified.

### Phase 3 — Hosted AI governance

1. Add entitlement and quota services.
2. Add explicit cloud-processing consent.
3. Add granular agent permissions and action confirmation.
4. Add retention, deletion, audit, and privacy controls.

## Final Recommendation

Hmm should not require an account for ordinary local note management. It should
require an account at the point where the user enables Hmm-hosted storage, cloud
OCR, LLM processing, AI agents, collaboration, or another server-funded
capability.

Authentication, synchronization, local privacy, and payment entitlement must be
modeled separately. This prevents the self-hosted IdP from becoming a single
point of failure for local notes while preserving the account controls necessary
for secure and sustainable web services.
