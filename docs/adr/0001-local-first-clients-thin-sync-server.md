---
status: accepted
date: 2026-11-25
---

# Local-first clients with a thin sync server

Hmm began with an enterprise client/server shape: every domain area (notes,
automobiles, gas logs, cheatsheets…) has a REST resource on `Hmm.ServiceApi`
and a matching API repository in the app, beside a local Drift repository —
the "interface plus two implementations" pattern behind `DataMode.cloudApi`.
As business logic moved into the app (calendar recurrence, contacts, video,
glucose, the notes query engine), the server copy fell behind: calendar,
contacts and videos are already unavailable in `cloudApi`, and every new
feature costs a second implementation in C#.

**Decision:** the app is the source of truth and holds the business logic.
The server keeps only what a device cannot do alone:

1. **Identity** — the Hmm IdP, as today. Optional in `local` and
   `cloudStorage` (#49, shipped 2026-11-25).
2. **Generic sync** of notes and vault attachments — one contract, the same
   shape OneDrive sync already uses (`docs/sync_contract.md`), instead of a
   REST resource per domain. Almost every domain object is already a note
   with JSON content (contacts, calendar events, gas logs, cheatsheet cards),
   so the server can sync them without understanding them.
3. **Sharing** — who owns a note and who may read or write it. This is the
   one capability OneDrive cannot give (it shares folders, not records, and
   has no per-record conflict rules between two people).
4. **Server-only services** — the AI engine gateway (#27), push
   notifications to other people, scheduled jobs, e-mail ingestion, a web
   viewer.

`cloudApi` stops being a separate set of API repositories and becomes "sync
to the Hmm server" — a third sync target beside OneDrive. New features are
built once, in the app; the server changes only when sync, sharing or a
server-only service changes.

## Considered options

- **Keep the per-entity REST API** — rejected: doubles every feature and the
  gap keeps widening; it was the right shape for a single-owner personal
  system, not for app-store users who expect the app to work offline and
  without an account.
- **Drop the server entirely (OneDrive only)** — rejected: no sharing
  between people, no server-side AI key, no notifications to others, and no
  natural paid tier (see Business model).
- **A full CRDT / operation-log sync engine** — not now: note-level
  last-writer-wins with the existing conflict rules is enough for one owner;
  revisit when shared notes get concurrent editors.

## Business model

Local-first apps earn from convenience and from what only a network can do,
not from holding data hostage. The split follows the architecture: **the
device is free; the network is paid.**

- **Free core** — everything on the device plus OneDrive sync with the
  user's own account; bring-your-own LLM key, called directly from the
  device. This builds trust, reviews and daily habit.
- **Hmm Plus (subscription, monthly or yearly)** — the thin server's
  capabilities:
  - **Household plan** as the headline: sharing a car's history, family
    contacts and calendars, a caregiver following glucose readings. Sharing
    is what genuinely needs the server, so it is the honest thing to charge
    for.
  - Web access, version history and a managed backup.
  - **AI included** — LLM features without the user's own key, through the
    server's engine gateway, with a monthly allowance (margin on usage).
- **Later: premium modules** — paid add-ons once the plugin architecture
  exists (for example CGM import and health reports, automobile reports).
- **Never:** ads or selling data — they contradict the privacy promise,
  which is the product's main advantage.

Principles: charge for what costs money to run (server, storage, AI), so
revenue covers the costs it creates; digital features are bought through the
stores' in-app purchase (Apple small-business rate 15%), with entitlement
checked on device from the store receipt so paid features still work offline;
plan for 2–5% of free users to convert, so Plus must be compelling to the
households that need sharing. The target user is a **household's life
admin** (cars, health, documents, family calendar) rather than "a notes app
with extras".

## Consequences

- The per-entity endpoints in the `Hmm` repo (automobiles, gas logs,
  cheatsheets, insurance, service records, …) become legacy once the generic
  sync endpoint exists; the API repositories in `hmm_console` go with them.
  This is a real migration on both sides and needs its own plan.
- Ownership moves from "the signed-in IdP user" to "the note's owner plus
  its sharing list"; the device owner id from #49 is the starting point.
- Cross-user server-side queries (reports across many people's data) are
  given up unless a specific service projects the data it needs.
- LLM calls follow the same split: direct from the device with the user's
  key in `local`/`cloudStorage`; through the server gateway in the server
  tier. Sensitive notes are never sent on either path (#26).
