# Day 2 — Design

**Date:** 2026-10-20 · **Phase:** 3, design · **Roles on point:** DBA, Developer

## Planned

Architecture, data model and ERD, Firestore schema, ADRs 1–3. Issue #19.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #26 | `ARCHITECTURE.md`, `DATA-MODEL.md` with ERD, ADRs 001–004, and the test cases the model implies | merged to `develop` |

Delivered a day earlier than the plan's clock — the stakeholder asked to bring
it forward, and the work was design, which had no dependency waiting on it.

## Decisions

Four, all written up properly in `docs/adr/`:

1. **ADR-001 — Flutter and Firebase.** One codebase for both platforms, no
   server of our own. Accepted costs: vendor lock-in, and no `africa-south1`
   region for Firestore.
2. **ADR-002 — turns are derived from an anchor, never stored as a pointer.**
   A `currentLeader` field needs something to advance it, and a phone that was
   off on the turnover day gets a stale answer. Arithmetic cannot be stale.
3. **ADR-003 — the local store is the read path.** Firestore writes into it in
   the background. The app opens to an answer, not a spinner.
4. **ADR-004 — journals live outside the family tree, keyed by author.**
   Privacy that depends on remembering an exception is privacy that fails on a
   busy day. Keyed at the root, the denial is structural.

Two model decisions that cost real structure and are worth it:

- **Cycles are epochs.** A single stored order would rewrite history whenever
  the family changed size. Epochs are the only reason R2.3 is possible.
- **Dates are `yyyy-mm-dd`, not timestamps.** A turnover is a calendar event.
  South Africa has no daylight saving, so nothing bites today — one member
  travelling is enough to expose it.

## Verification worth noting

The rota arithmetic was **executed before the document was merged**, not merely
reasoned about: six weeks without skips, a skipped week, two skips in one week,
all seven days of a week, six months untouched, and 521 consecutive weeks
checked for drift — zero mismatches. The cases are now written into
`DATA-MODEL.md` as the unit tests Day 3 owes, each naming the requirement it
defends.

Three fields were cut during writing for tracing to no requirement:
`member.email`, `member.avatarUrl`, `family.lastActiveAt`.

## Defect found at close of day

**#19 did not close itself, and the first draft of this log claimed it had.**

The work shipped in #26, but that PR's body read "From #19:" above the
acceptance criteria rather than `Closes #19`. The workflow added yesterday ran,
found no keyword and correctly did nothing. The keyword *was* in the squash
merge message — which the workflow does not read, and which GitHub ignores for
a non-default branch.

So yesterday's automation worked and today's author did not. Two lessons, both
cheap today and expensive on day 11:

1. The log is written from the repository, not from memory. This entry claimed
   a closure that had not happened, and was corrected before merge because the
   claim was checked.
2. A convention that depends on remembering is the same failure as the privacy
   model ADR-004 rejects. Filed as #28: PR hygiene now requires a closing
   keyword on any PR labelled `type:story` — the exact set that implements a
   backlog item. Chore and day-log PRs legitimately close nothing and are
   unaffected.

#19 was closed by hand with that explanation on it.

## Open questions

No new ones. **Q3** (individual sign-in vs one shared install) was pinned down
rather than answered: it is load-bearing for journal privacy only, ADR-004 says
exactly what supersedes it if the answer is "shared", and the rota, epochs,
skips and verse are unaffected. Days 3–6 are not blocked by it; Day 7 is.

**Q1** (the family's turnover weekday) is still open and still blocks Day 6.
The design takes it as configuration, so no code depends on the answer.

## Blocked

Nothing.

## Tomorrow — Day 3, the cycle engine

`leaderOn(date)` in pure Dart with no I/O, and the unit tests listed at the
bottom of `DATA-MODEL.md`. Issue #2, with the QA test strategy (#20) alongside
it.
