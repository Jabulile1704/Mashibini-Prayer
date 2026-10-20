# ADR-004 — Journals live outside the family tree

**Status:** Accepted · **Date:** 2026-10-20 · **Deciders:** DBA, QA

## Context

R4.2 says a journal entry is readable only by the person who wrote it, and N3
says that must be enforced in the database rather than only in the UI. The
family's own data — members, cycle, skips — is deliberately shared with
everyone in the family.

So one document tree has two opposite access rules in it.

## Decision

Journal entries do not live under `families/`. They live at the root, keyed by
their author:

```
journals/{uid}/entries/{entryId}
```

with one rule:

```
match /journals/{uid}/{document=**} {
  allow read, write: if request.auth.uid == uid;
}
```

## Why not nest them under the member

`families/{familyId}/members/{memberId}/journal/{entryId}` reads more naturally
and is wrong for one reason: it puts private data inside a tree whose whole
purpose is to be shared. Every future rule, every `collectionGroup` query,
every "let the family see each other's profiles" change then has to remember
to carve an exception back out. Privacy that depends on remembering is privacy
that fails on the day somebody is in a hurry.

Keyed by author at the root, there is nothing to remember. No family-level
query can reach it, because it is not in the family's tree at all.

## Consequences

**Good**

- The denial is structural, and provable with a rules unit test in CI (Day 8).
- A member leaving the family does not orphan or expose their entries.
- The rule is one line, which means it can be read and understood in full.

**Bad, and accepted**

- An entry does not know which family it belongs to, so "show the journal
  entries from the week I led" needs the rota computed client-side and joined
  by date. The rota is pure and local (ADR-002, ADR-003), so this costs nothing
  but a little code.
- `collectionGroup` queries across all journals are impossible by design. Good:
  nothing should ever want one.
- If **Q3** resolves to a single shared install, `uid` is the same for everyone
  and this structure protects nothing. In that case journals must become
  device-local and unsynced, and the privacy claim in the UI must shrink to
  match. That would supersede this ADR rather than quietly weaken it.
