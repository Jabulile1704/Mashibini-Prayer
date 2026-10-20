# ADR-002 — Derive turns from an anchor date

**Status:** Accepted · **Date:** 2026-10-20 · **Deciders:** DBA, Developer

## Context

The app's entire purpose is answering "whose week is it?". There are two ways
to know.

**Stored pointer:** keep `currentLeaderIndex` and advance it every week.

**Derived:** store the date the cycle started and compute the answer for any
date.

The stored pointer is what most people reach for first, and R1.3 was written
specifically to forbid it.

## Decision

Store the rules — `cycle.effectiveFrom`, `cycle.order`,
`family.turnoverWeekday` — and compute the leader for any date:

```
position = (weekIndex(d) + skipsBefore(d)) mod order.length
```

No field is advanced. Nothing runs weekly.

## Why the pointer is wrong

1. **Something has to advance it.** A phone that is off, flat, in a drawer or
   freshly reinstalled on the turnover day gets a stale answer. A scheduled
   function to advance it is a backend job, a cost and a new failure mode, for
   arithmetic the client can already do.
2. **Drift compounds.** "Add seven days to the last value" accumulates every
   error it ever makes. Counting whole weeks from a fixed anchor cannot drift,
   because nothing carries forward.
3. **It cannot answer about the past.** "Who led in March?" is unanswerable
   from a pointer, and both the journal and the skip history want it.
4. **Concurrency.** Four devices that might each advance the same counter is a
   race for no reason. A derived value has nothing to race over.

## Consequences

**Good**

- Correct after any gap, with no catch-up work: six months closed costs one
  modulo.
- Trivially testable — every week of the next decade is a unit test, and
  `leaderOn(date)` takes the date as an argument so no test waits for Tuesday.
- Past and future are the same question, so "the next eight turns" (R1.5)
  needs no extra machinery.

**Bad, and accepted**

- Changing the family cannot be a simple edit: a new `n` would re-derive
  history. Handled by versioning the cycle into epochs, which is more
  structure than a pointer needs (see `DATA-MODEL.md`).
- Skips must be stored as exceptions and folded into the index, so the
  computation is a little more than a modulo. Still pure, still fast, still
  testable.
