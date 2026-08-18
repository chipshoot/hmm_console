# Cheatsheet Source Picker Audit

**Date:** 2026-08-15  
**Status:** Follow-ups recommended; no release-blocking findings  
**Scope:** Uncommitted cheatsheet source-scoping and source-picker changes

## Purpose

This document records the review of changes that rank source notes by the
selected cheatsheet template, exclude infrastructure notes, and propagate the
template ID from the cheatsheet designer into the source picker.

## Review Roles

The audit used the relevant reviewer definitions from
`~/.claude/plugins/cache/ecc/ecc/2.0.0/agents`:

- `flutter-reviewer`
- `code-reviewer`
- `pr-test-analyzer`
- `silent-failure-hunter`

## Findings

### 1. Catalog lookup failure disables source binding

**Severity:** Medium  
**Location:** `lib/features/cheatsheet/presentation/widgets/source_picker.dart:54`

The picker now depends on both the note repository and the catalog repository.
If `getCatalogs()` fails, the entire picker enters its error state even when the
notes themselves loaded successfully. The error view exposes the exception text
and offers no retry action. Existing picker tests always use a successful fake
catalog repository, so this failure path is not covered.

Recommended follow-up:

- Decide whether catalog metadata failure should block binding or degrade to an
  explicitly unranked list of notes.
- If it blocks binding, show a user-safe message with a retry affordance.
- Add tests for catalog lookup failure and, ideally, a failure on a later page
  of note loading.

### 2. New headings bypass localization

**Severity:** Medium  
**Locations:**

- `lib/features/cheatsheet/domain/source_scope.dart:56`
- `lib/features/cheatsheet/presentation/widgets/source_picker.dart:132`

The new user-facing strings `Vehicle` and `Other notes` are hard-coded in
English despite the project's `AppLocalizations` convention. Keeping `Vehicle`
inside `SourceDomain` also couples domain logic to presentation copy.

Recommended follow-up:

- Store a locale-neutral domain identifier in `SourceDomain`.
- Resolve both headings through `AppLocalizations` in `SourcePicker`.
- Add the English and Chinese ARB entries and regenerate localization output.

### 3. Unrelated iOS lockfile change

**Severity:** Low  
**Location:** `ios/Podfile.lock`

The addition of `local_auth_darwin` does not appear related to the cheatsheet
source-picker work. Confirm that it is intentional before including it in the
same commit.

## Suggested Additional Coverage

Template propagation is covered for newly created cards. An edit-flow binding
test should also assert that the loaded card's `templateId` reaches the picker,
protecting against future editor-loading timing regressions.

## Verification

- 45 focused cheatsheet tests passed.
- Flutter static analysis passed with no issues.
- No swallowed exceptions, empty catches, or hidden fallback behavior were
  found in the changed code.
- No correctness or security blocker was identified.
- The audit itself made no production-code changes.

## Verdict

Approve with follow-up work for resilient catalog-loading behavior and
localization. The current findings are not release blockers, but addressing them
will improve failure recovery, test coverage, and multilingual consistency.
