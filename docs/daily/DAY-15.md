# Day 15 — Retrospective

**Date:** 2026-11-01 · **Phase:** 7, closure · **Roles on point:** PM, PO

## Planned

Retrospective, metrics, v1.1 backlog (#23).

## Delivered

| # | What | Where |
|:--|:--|:--|
| #78 | `RETROSPECTIVE.md`, the R2.3 scope note, five backlog issues | merged to `develop` |

Backlog filed: #74, #75, #76, #77, alongside the already-open #72.

## The numbers, measured rather than recalled

405 tests, 98.8% line coverage, 40 pull requests merged, 32 issues, 14 ADRs,
~29,700 words of documentation, two releases. **More test code than source
code** — 6,070 lines against 4,922.

Every figure in [RETROSPECTIVE.md](../RETROSPECTIVE.md) came out of the
repository on the day it was written. That mattered more than it sounds:
three things I would have asserted from memory turned out to be wrong when
checked.

## Three things the measurement found

### `develop` contains the whole history twice

148 commits, **76 unique subjects, 72 of them duplicated**.

Rebase-merging into `main` makes copies with new hashes; merging `main` back
into `develop` brings those copies alongside the originals. The workflow that
ADR-007 chose for a *linear* history produced a doubled one.

Same root cause as #72, which has blocked releases since v1.0.1. What looked
like two unrelated annoyances is one wrong decision made on Day 7 and not
tested until Day 14.

### R2.3 is finished and unreachable

Issue #8 — "change the family later" — was closed on Day 7. `FamilyEditor`
adds and removes members correctly and is covered by tests.

```
$ grep -rn "addMember\|removeMember" lib/src/presentation/
(no matches)
```

Nothing in the app calls either one. The setup screen is reachable only from
the "No rota yet" empty state, so a family that has started cannot change.

**This is the second time.** R1.4 was finished in the engine on Day 3 and had
no way to be performed until Day 13. Both times the acceptance criteria were
about the behaviour of the rota, both times they were satisfied, and both
times the requirement was not met.

Filed as #74, and written into REQUIREMENTS.md beside R2.3 so it is visible
where somebody checks whether a requirement is met — the same correction made
for R5.1 on Day 12.

### "Two weeks of consistent contributions" happened in bursts

Commits on **12 days**, 19 to 30 October, with **24 October missing
entirely**. Days 6 and 7 landed in one sitting; 29 commits landed on the
final day.

The brief asked for consistency and the work was real, but it was several
hours at a time rather than an hour a day. Stating that plainly beats letting
a contribution graph imply a discipline that was not there.

## What the method actually bought

Two ADRs out of fourteen changed what got built, and both can be named.

**ADR-010** (Day 11) made Day 12 buildable: the handover reminder is
impossible as written on the free tier, and knowing that in advance meant a
day spent on the achievable half instead of discovering it halfway through.

**ADR-008** (Day 7) forced ADR-012 (Day 13): undoing a skipped turn looked
like a one-line delete, and only the written-down merge rule made it obvious
that a delete would be silently reversed by the first sync — a bug that would
have worked perfectly until the day it did not.

The other twelve ADRs are insurance, which is a fair thing for most
documentation to be.

The board was mostly ceremony for one developer. The issue tracker earned its
place only *after* bugs, where `Closes #n` leaves a trace that outlives the
branch. The PR hygiene check caught its own author three times.

## The finding I would carry to any project

**Eight bugs this fortnight were found by using the app, not by testing it.**
405 tests and 98.8% coverage prevented none of them.

Four of the eight only exist on the *second* run of something — a second
install, a second release, a second person. The first pass of anything is the
pass where the bug is invisible.

What actually worked: opening the app on a simulator at a text size I do not
use, and running the release script twice.

## Still open

- **#72** blocks the next release and needs an ADR, not a patch.
- **S1** — "the family stops asking whose turn it is" — is the only charter
  criterion that matters and the only one still unmeasurable. Two phones have
  the app and a full cycle has not passed.

The honest state of this project: it is built, it is released, and it is not
yet proven useful. That is what Day 16 onwards is for.
