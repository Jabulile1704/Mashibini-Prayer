# Day 6 — Setup

**Date:** 2026-10-23 · **Phase:** 4, implementation · **Roles on point:** Developer, PO

## Planned

Family setup: members, their order, the turnover day and the anchor (R2.1,
R2.2). Issues #6 and #7.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #40 | `RotaSetup`, `DeviceSettingsRepository`, the setup screen, 182 tests | merged to `develop` |

The app is now usable end to end by someone who has never seen it: open, set up
a rota, and be told whose week it is.

## Q1 is closed, and not by answering it

**Q1 — which weekday does the family's week turn over on?** — has been open
since Day 1 and was recorded as blocking today.

It is closed because the design removed the need for it. The setup screen
**asks**. The weekday is a required answer and the app stores whichever one the
family chooses; the picker opens on Sunday purely as a starting position, and
nothing is written until the button is pressed.

That is the better outcome. A project default would have been a guess wearing a
UI, and it would have been wrong for any family whose week turns over on a
Friday. Recorded in `REQUIREMENTS.md` with the reasoning, rather than ticked off
as though it had been answered.

**Q3** remains genuinely open and genuinely blocking, for Day 7.

## Decisions

1. **The order is rotated so the current leader sits first.** The alternative —
   keeping the typed order and pushing the anchor back into the past — would
   make `startedOn` claim the rota began before the family had opened the app.
   A cycle has no first member, only an order, so rotating costs nothing and
   the sequence after the current leader is exactly as typed.
2. **"Which member is this phone" is not part of `Family`.** The family is
   shared data; "who am I" differs on every device that reads it. In the shared
   aggregate, four phones would fight over one field. It also keeps the
   question independent of Q3.
3. **Weekday names are hard-coded English.** `AppLocales` declares English
   only. If that changes, this is the first thing that must — and it will be
   obviously wrong rather than subtly wrong, which is the best a hard-coded
   string can offer.
4. **One unreachable `catch` is kept and left uncovered.** Everything
   `RotaSetup` refuses, the screen already refuses with a sentence a person can
   act on. The catch exists for the day those two sets of rules drift apart,
   which is the only route by which a domain invariant reaches a user. Four
   uncovered lines, commented in the source, rather than a 100% figure that
   hides a deleted safeguard.

## The hygiene check caught its author

This PR's first CI run **failed**, on its own repository's rule: the body must
contain a "How it was verified" section, and I had replaced that heading with
nicer prose.

The check was right. The section exists so that it can always be found, and a
heading that reads better to its writer is not worth a convention that stops
being enforceable. Restored rather than relaxed.

That is the third time a check has caught something that would otherwise have
gone through — the issue-link keyword on Day 2, the American date order on Day
5, and this. They are earning their place rather than decorating the repository.

## Verified by hand

From a fresh install with its storage cleared: typed two names, left the
turnover on Sunday, chose Sisi as this week's leader, pressed *Start the rota*.

```
This week
Sisi
until Saturday, 24 October 2026
────────────────────────────────
→  Jabulile
   from Sunday, 25 October 2026
```

Then terminated the app and relaunched it. The rota was still there.

That also finishes what Day 4 left open — "nothing yet proves persistence
survives a real restart on real hardware". #37 closed it with the package's own
in-memory implementation; this closes it by hand on a device.

## Open questions

**Q3** — individual sign-in or one shared install — blocks Day 7 and decides
whether journal privacy can be enforced in the database at all. If the answer
is "shared", ADR-004 is superseded and journals become device-local and
unsynced. It is the last question that genuinely needs the family rather than
the project.

## Blocked

Nothing today. Day 7 is blocked on Q3 unless a provisional answer is chosen,
and that one cannot be dissolved by design the way Q1 was: it is a fact about
how the family will use the app, not a setting.

## Tomorrow — Day 7, Firebase

The project, the auth decision and the Firestore wiring (R2.3, R6.2). Issues #8
and #9. Needs the user's own Firebase account for the parts that cannot be done
on their behalf.
