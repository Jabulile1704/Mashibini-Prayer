# ADR-012 — A skip is withdrawn, never deleted

**Status:** Accepted · **Date:** 2026-10-30 · **Deciders:** Developer, DBA

## Context

R1.4 lets the family pass over somebody's turn. Day 13 added the control, and
with it the obvious companion: a way to take a skip back. A skip shifts the
whole rota by one week, so a mis-tap is not cosmetic — it changes who leads
for every week after it until somebody notices.

The question is what "take it back" does to the stored record.

The tempting answer is to remove it from `Family.skips`. Nothing in the app
today would notice: there is one device, the list is loaded and saved whole,
and a removed element stays removed.

## The problem with removing it

ADR-008 settled that families merge as a **union of append-only logs**, keyed
by id. That is what makes two phones converge without a server deciding a
winner, and it is the design the whole offline story rests on.

A union has no concept of absence. If phone A removes skip `s7` and phone B
still holds it, the merge is `{s7} ∪ {} = {s7}` — the skip comes back. Worse,
it comes back *silently and later*, on whatever day the two phones next sync,
long after anybody remembers making the change. The rota would shift under a
family that had already corrected it.

This is not a hypothetical about future code. It is a property of the merge
that exists today, in `FamilyMerge`.

## Decision

**`SkippedTurn` carries a `withdrawn` flag, and withdrawing sets it to true.
The record is never removed.**

Three rules make that safe:

1. **The engine ignores withdrawn skips.** `_skipsUpTo` skips over them, so a
   withdrawn skip moves nothing.
2. **The flag only ever goes false → true.** Merging two versions of the same
   id takes the withdrawn one, whichever side is holding it. That is a lattice
   join, not a tie-break: it gives the same answer in either argument order and
   the same answer again if the merge runs twice, which is exactly what
   `FamilyMerge` promises.
3. **Skipping the same week again appends a new record with a new id.** The
   withdrawn one is never revived, so rule 2 holds without costing anybody the
   ability to change their mind twice.

The merge helper grew a `resolve` parameter for this. Every other log in the
family resolves a collision by *preferring a side* — a tie-break, which is a
guess. This one does not have to guess, and where a type can decide for itself
it should.

## Consequences

**The log grows.** A family that skips and un-skips the same week repeatedly
accumulates records. At a handful of skips a year this is not worth solving;
ADR-006 already sets the size budget for the family document and this stays
far inside it.

**A withdrawn skip is still history.** That is a feature, not a cost: it can
be shown later ("this week was going to be skipped") and it keeps the log
honest about what the family actually decided.

**`withdrawn` is written only when true.** A family that has never taken a
skip back carries no such field, and an absent field reads as false — which is
also what every document written before this decision means. No migration.

## Alternatives considered

**A separate `cancellations` log.** Also correct, and also a union. Rejected as
a fourth log and a second id space to serialize, merge and reason about, for no
behaviour the flag does not already give.

**Removing it, and fixing the merge later.** Rejected explicitly. Sync is not
wired yet (`RemoteFamilySource` has no implementation), so removal would work
perfectly until the day it didn't — and the failure would be a rota quietly
changing, which is the hardest kind of bug to attribute. The cost of doing it
right today is about thirty lines.
