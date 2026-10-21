# Day 3 — The cycle engine

**Date:** 2026-10-21 · **Phase:** 4, implementation (and 5, testing) · **Roles on point:** Developer, QA

## Planned

The cycle engine — whose week is it — in pure Dart, fully unit tested
(R1.1, R1.3). Issue #2, with the QA test strategy (#20) alongside it.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #31 | `RotaEngine`, `CalendarDate`, `Member`, `Cycle`, `SkippedTurn`, `Turn`, week arithmetic, 71 tests, `TEST-STRATEGY.md`, ADR-005 | merged to `develop` |
| #32 | Filed: the issue-closing workflow cannot report its own failures | open, S4, deferred to M5 |

`lib/src/domain` is at **100% line coverage**, and the domain imports nothing
but `dart:core`.

## Decisions

1. **ADR-005 — the domain has its own `CalendarDate`.** `DateTime` always
   carries a time and an offset; a type that cannot hold a time cannot leak
   one, and there is nowhere in it to put a `DateTime.now()`.
2. **`turnOn` returns `Turn?`, and null means the rota had not started.** Not
   an exception: the requirements call this an error state the UI must render,
   and throwing would push that decision into a `catch` block on Day 5.
3. **Unresolvable member ids are dropped, and surfaced.** `DATA-MODEL.md` says
   log and drop, but logging is I/O and the domain does none. So the engine
   drops them and exposes `unresolvedMemberIds` for the data layer to log —
   the domain never learns what a log is.
4. **`SkippedTurn`, not `Skip`.** `package:flutter_test` exports its own
   `Skip`. The alternative was `hide Skip` in every test file forever, which
   is a rule that depends on remembering — the failure mode this project has
   now been bitten by twice. Renamed so collision is impossible.

## Verification worth noting

**The coverage target was measured, not claimed.** `TEST-STRATEGY.md` was
written first and set 100% as the expectation for the domain. Measuring gave
**83.3%**: the engine and week arithmetic were complete, the value types were
not. The missing tests were written rather than the sentence softened.

**The engine was mutation tested.** The strategy says a test never seen red is
not known to watch anything, so five faults were introduced and reverted one
at a time:

| Fault | Tests that caught it |
|:--|--:|
| Skip term inverted | 3 |
| Week index accumulates instead of counting from the anchor | 16 |
| Governing cycle `isBefore` instead of `isOnOrBefore` | 15 |
| Skip bound `isAfter` instead of `isOnOrAfter` | 3 |
| Week start off by one day | 25 |
| Turn ends 7 days after it starts instead of 6 | **1** |

The last row was the point of the exercise: a wrong `weekEnd` was caught by a
single assertion, meaning nothing checked that consecutive turns abut. A
contiguity test was added whose failure message prints both dates. 69 → 71.

**A false alarm, recorded because the log is written from the repository.**
Immediately after merging #31, #20 appeared not to have closed, and the first
read of the evidence was that the close had failed silently behind `|| true`.
It had not: the workflow log shows `✓ Closed issue #20`, and the check had
simply been made before the run finished. The real lesson is to verify after
the workflow completes, not after the merge. The `|| true` weakness is real
but latent, and is filed as #32 rather than fixed inside today's scope.

## Open questions

No new ones. **Q1** (turnover weekday) is still open and still blocks Day 6 —
the engine takes it as a constructor argument, so no code depends on the
answer. **Q3** (individual sign-in vs shared install) still blocks Day 7.

## Blocked

Nothing.

## Tomorrow — Day 4, persistence

The repository abstraction and a local store, with fakes for tests (R6.1).
Issue #5. The engine stays untouched: it takes data, it does not fetch it.
