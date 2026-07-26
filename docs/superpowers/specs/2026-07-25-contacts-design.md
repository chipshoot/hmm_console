# Contacts — Design Spec

**Date:** 2026-07-25
**Status:** Approved (brainstorming) — ready for planning
**Scope:** a Contacts domain module on **both backend (`Hmm`) and client (`hmm_console`)**, modeled by **composition** (note-content, like the Automobile/GasLog module). Prerequisite for the Cheatsheet feature.

## Goal

A **Contacts** address book of **people and organizations** — yourself, family members (wife, dad, …), and service providers (doctor, pharmacy, insurer). It is the single source of truth for person/org details that the **Cheatsheet** feature binds to, and the basis for future **family information sharing** (server-side, API-enabled).

## Why now / relationship to Cheatsheets

The cheatsheet spec (`2026-07-23-cheatsheet-cards-design.md`) is **blocked on this feature**: its Health card is entirely person-based and its Accident Claim card needs the driver's name/phone/address. Cheatsheet rows reference a contact by the contact's **owning-note UUID + field key** (this note-content model gives contacts a stable cross-device id, resolving cheatsheet defect #4). Build order: **Contacts -> Cheatsheet v1 -> Cheatsheet Phase 2.**

## Locked decisions (from brainstorming)

| Area | Decision |
|------|----------|
| Scope | **People + organizations.** `contactType: person | organization`. |
| Storage | **Note-content, GasLog-style** — a typed `Contact` entity serialized into an `HmmNote` (`Contact:{id}` subject + fixed `Hmm.Contact` catalog). Rides the note pipeline in **all three data modes**. **No schema change.** |
| API | **First-class `/v1/contacts`** built over the note-content (exactly as `/v1/automobiles/{id}/gaslogs` is over GasLog note-content). The API is the primary service path — used by cloudApi mode and future family sharing, **not** legacy. |
| Both stacks | Backend module (entity + serializer + validator + manager + controller) **and** client feature module (entity + note serializer + local store + states + UI). Mirrors the Automobile module. |
| Fields added | `isSelf`, `relationship` (category + optional label), organization support — on top of names / phones / emails / addresses. |
| Self | `isSelf` marks the "me" contact; **at most one** (enforced). |
| Author.Contact | **Out of scope.** The author's own contact info stays on the existing relational `Contact` for now; a future refactor moves it to `/v1/authors/{id}/contact`. `/v1/contacts` is repurposed for this note-content address book. |

## Non-goals (v1)

- **Family information sharing** (multi-user, server-side) — future; the API design leaves room for it.
- **Author.Contact migration** to a nested route — separate future refactor.
- Organization extras (opening hours, logo, multiple branches).
- Contact photos/avatars, import from device address book, dedup/merge.

---

## Architecture

Composition (never inheritance), like `GasLog`/`Automobile`:

- **Backend (`Hmm`)** — a Contacts domain module: `Contact` domain entity + `ContactJsonNoteSerialize` + `ContactValidator` + `ContactManager` (over `EntityManagerBase`/`EntityValidatorBase`/`EntityJsonNoteSerializeBase`) + a `/v1/contacts` controller. Stored as `HmmNote` content (`Contact:{id}` subject, `Hmm.Contact` catalog) — **no new table, no schema change.** The manager owns CRUD, `isSelf`-single enforcement, and shape validation.
- **Client (`hmm_console`)** — a `contacts` feature module:

```
lib/features/contacts/
  domain/entities/   contact.dart, contact_phone.dart, contact_email.dart, contact_address.dart
  data/              contact_note_serializer.dart, contact_repository.dart, contact_remote_datasource.dart
  states/            contacts_list_state.dart, contact_edit_state.dart
  presentation/      screens/{contacts_list, contact_detail, contact_edit}, widgets/{contact_tile, labeled_field_editor}
```

In `local`/`cloudStorage` the client reads/writes the note-content directly (note pipeline); in `cloudApi` it goes through `/v1/contacts`. Same note-content underneath — one source of truth, two access paths.

## Data model

```dart
enum ContactType { person, organization }

class Contact {
  final String id;                 // uuid (also the owning HmmNote's stable identity)
  final ContactType contactType;
  final String? firstName;         // person
  final String? lastName;          // person
  final String? organizationName;  // organization
  // displayName is computed: person -> "First Last"; org -> organizationName.
  final List<ContactPhone> phones;
  final List<ContactEmail> emails;
  final List<ContactAddress> addresses;
  final ContactRelationship relationship;
  final bool isSelf;               // at most one across all contacts (enforced)
  final String? notes;
  final bool isActivated;          // soft-deactivate (matches existing pattern)
}

class ContactPhone   { final String label; final String number; }   // label: mobile|home|work|other
class ContactEmail   { final String label; final String address; }  // label: personal|work|other
class ContactAddress { final String label; final String value; }    // label: home|work|other

class ContactRelationship {
  final RelationshipCategory category; // see enum
  final String? customLabel;           // optional free text when category == other
}

enum RelationshipCategory {
  self, spouse, parent, child, family, friend, doctor, pharmacy, insurer, other
}
```

Notes:
- **displayName** is derived, not stored, so person and org both present a single name to the UI and to cheatsheet binding.
- **Stable identity** = the contact's owning `HmmNote` UUID; this is what a cheatsheet row's `noteUuid` references, and it resolves across devices.
- Cheatsheet-bindable field keys (v1): `displayName`, `firstName`, `lastName`, `organizationName`, `phone` (primary), `email` (primary), `address` (primary), plus label-qualified variants finalized in the plan.

## Storage

- Each contact is an `HmmNote` under a fixed `Hmm.Contact` catalog with subject `Contact:{id}`; the entity JSON is the content.
- Syncs via existing note storage + pipeline in all data modes; **no schema change.**
- `isActivated=false` is the soft-delete (contacts referenced by a cheatsheet are deactivated, not hard-deleted, so references degrade to "source removed" rather than dangling).

## API (`/v1/contacts`)

- `GET /v1/contacts` — list, with query filters `?type=person|organization`, `?relationship=<category>`, `?isSelf=true`, plus standard pagination.
- `GET /v1/contacts/{id}` — one contact.
- `POST /v1/contacts` — create (rejects a second `isSelf`).
- `PUT /v1/contacts/{id}` — update (same `isSelf` guard).
- `DELETE /v1/contacts/{id}` — deactivate (soft).
- Top-level resource (contacts have no owning parent, unlike gaslogs under an automobile). Built over the note-content via `ContactManager`. Leaves room for future sharing sub-routes.

## Client UI

- **Contacts list** — searchable; grouped/filterable by type and relationship (Family / Providers / etc.); a create (+) action.
- **Contact detail** — read view with **tap-to-call / tap-for-Maps** (same affordances cheatsheets use); edit action.
- **Contact edit/create** — form: type toggle (person/org), name field(s), labeled repeatable phones/emails/addresses, relationship picker, `isSelf` toggle (guarded to one), notes.
- Reachable from primary navigation; exact entry point pinned in the plan.

## isSelf enforcement

At most one contact may have `isSelf=true`. Enforced in `ContactManager` (backend) and mirrored client-side: setting `isSelf` on a contact clears it from any other. Tested on both create and update paths.

## Testing

- **Serializer:** `Contact` <-> `HmmNote` JSON round-trips (person and organization; labeled phones/emails/addresses; empty lists); unknown/absent fields tolerated.
- **Manager/API:** CRUD; `isSelf`-single enforced on create and update; soft-deactivate; query filters (`type`, `relationship`, `isSelf`).
- **Multi-mode (client):** a contact created in `local` mode reads back from note-content; the same entity resolves via `/v1/contacts` in `cloudApi` — one source of truth, both paths.
- **UI (widget):** list grouping/search; detail tap-to-call / tap-for-Maps with the right value; edit form adds/removes labeled fields; `isSelf` toggle clears any other self.
- **Cross-feature:** a cheatsheet row referencing a contact's note UUID resolves the intended field; deactivating the contact degrades the row to "source removed" (not a crash).

## Future phases (out of v1)

- **Family information sharing** — share selected contacts/cheatsheets with other users (server-side, `/v1/contacts` sharing sub-routes + permissions).
- **Author.Contact** re-homing to `/v1/authors/{id}/contact`.
- Contact photos, device-address-book import, dedup/merge, organization extras.
