# ADR-008 — Merging is a union of append-only logs

**Status:** Accepted · **Date:** 2026-10-25 · **Deciders:** DBA, Developer

## Context

R6.2 asks for two things that usually pull against each other:

> **Given** two members change the cycle while offline, **when** both
> reconnect, **then** the result is deterministic and the losing change is not
> silently discarded.

Last-write-wins gives determinism and discards. Operational transforms and
CRDTs give neither problem and cost more than this app is worth. ADR-003
sketched last-write-wins per document as the Day 7 default; writing the tests
showed that is not good enough for the cycle, because two people both adding a
family member is an ordinary Sunday, not an edge case.

## Decision

Merging is a **union keyed by id** over three append-only collections —
members, cycles, skips — plus last-write-wins for the family's scalar fields,
which have no history to keep.

Nothing is overwritten. Where two devices genuinely collide, both epochs
survive in the family and the rota resolves to one of them by a rule that does
not depend on who synced first.

Three properties make it work, and each is tested as a property rather than as
an example:

1. **Commutative.** `merge(a, b)` and `merge(b, a)` produce the same family,
   compared on a fingerprint of everything a merge can touch.
2. **Idempotent.** Merging a result with either input again changes nothing.
3. **Canonically ordered.** The output is sorted — members by id, cycles by
   date then id, skips by week then id.

## Why canonical ordering is not tidiness

Two phones merging the same pair in opposite orders produce equivalent lists
in different sequences. Each writes its document back. Each then sees the
other's document as a change, merges again, writes again — syncing at each
other indefinitely over a difference that means nothing.

Sorting the output ends it. Equivalent inputs produce byte-identical families,
so the second merge has nothing to write.

## What this exposed, and the change it forced

The merge tests failed the first time they were run, and the failure was not in
the merge.

Ids were being **counted from local state**: the fifth member was `m5`, the
second cycle `c2`. That is correct on one phone and silently wrong on two —
both devices mint `m5` for *different people*, the union collapses them by id,
and one person's addition disappears. Precisely what R6.2 forbids, produced by
code written before R6.2 was implemented.

So ids are now generated, not counted. `IdGenerator` is an interface in the
domain; `RandomIdGenerator` in the data layer draws eleven characters from a
28-character alphabet with no vowels and no look-alikes. The alphabet is
chosen so an id can be read down a phone line or copied by hand without `0`
becoming `O`, and so that an id never accidentally spells a word.

Randomness is injected rather than reached for, because the domain imports
nothing but `dart:core` and because a test that asserts on an id needs to know
what it will be.

## Consequences

**Good**

- The requirement is met by the shape of the data rather than by a policy that
  has to be remembered. A union has no loser to discard.
- The same mechanism handles a third device, or a restore from backup, with no
  extra thinking.
- Conflicts are visible. Two epochs on the same date mean two people changed
  the rota that week, and both are in the history to be looked at.

**Bad, and accepted**

- Cycles accumulate. A family that reorganises often grows a longer log, and
  nothing prunes it. At one epoch per change and a handful of changes a year,
  the first pruning conversation is decades away.
- A genuine disagreement is not surfaced to anybody. If two people both change
  the rota for the same week, one of them silently governs. Making the app
  *say* so is a real feature, and it belongs to v1.1 rather than being
  pretended at here.
- Scalar fields — the family's name and turnover weekday — still use
  last-write-wins, decided by which side has more history. Two people renaming
  the family in the same hour will lose one of the names. That is a far smaller
  loss than losing a person from the rota, and it is the one place this ADR
  accepts a discard.
