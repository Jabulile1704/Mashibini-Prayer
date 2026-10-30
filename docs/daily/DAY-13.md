# Day 13 — Hardening

**Date:** 2026-10-30 · **Phase:** 5, hardening · **Roles on point:** QA, Developer

## Planned

Skip a turn (#16, R1.4), offline and empty states, accessibility pass
(#21, N5 and N7).

## Delivered

| # | What | Where |
|:--|:--|:--|
| #61 | `skipTurn` / `unskipTurn`, the weeks-ahead screen, ADR-012 | merged to `develop` |
| #62 | Text-scale sweep, four empty states, semantic labels, journal drafts | merged to `develop` |

402 tests, analyzer clean. R1.5 (#17) closed alongside R1.4, because the
screen that lets you skip a week is the screen that shows the eight weeks
ahead, and that is R1.5's criterion exactly.

## A requirement can be finished in the code and absent from the app

The engine has counted skips into the rota position since **Day 3**. The
merge has carried them since Day 4. The JSON has round-tripped them since
Day 4. Every one of those had tests, and all of them passed.

There was no way to record a skip. R1.4 had been half built for ten days
and nothing said so, because everything that existed worked.

What would have caught it: the acceptance criteria are written from the
family's point of view — *"when their turn is skipped"* — and nothing in
the app could perform that verb. A requirement is not met by the data
model being ready for it.

## Undo forced a decision that today's code could not see

Skipping shifts the whole rota by one week, so a mis-tap changes who leads
every week after it. Undo is not optional.

The obvious implementation — remove the record — works perfectly today.
There is one device, the list is loaded and saved whole, and nothing would
notice.

It would break the day sync lands. ADR-008 merges families as a **union of
append-only logs**, and a union has no concept of absence: `{s7} ∪ {} =
{s7}`. A skip deleted on one phone comes back from the other, silently, on
whatever day the two next sync — long after anybody remembers correcting
it, and presenting as a rota that changed by itself.

So a skip is **withdrawn**, never deleted (ADR-012). The flag only ever
goes false → true, and a collision resolves to the withdrawn version
whichever side holds it. That is a lattice join rather than a tie-break:
the same answer in either argument order, and the same answer again on a
second merge — which is what `FamilyMerge` already promises for everything
else. Re-skipping appends a new record, so the one-way rule costs nobody
the ability to change their mind twice.

Thirty lines, against a bug that would have been nearly unattributable.

## Three bugs the tests could not have found

This is the day's real lesson, and it arrived three times.

**Every button on the schedule screen was dead after one tap.** The screen
announces a change for screen readers via the accessibility platform
channel. With no screen reader running there is no listener, the send never
completes, and the awaited call never returned — so the `finally` clearing
the busy flag never ran. The widget tests passed throughout, because the
test binding answers that channel immediately. The regression test now
installs a handler that never replies, which is what the device does.

**The Journal's empty state overflowed at AX5.** The new text-scale sweep
pumped every screen at 3.1x and passed — because it seeded a family and an
entry first, so it only ever rendered the *populated* screens. An empty
state is not a smaller layout; it is a different one, a centred column with
nothing to scroll. The sweep now renders both states of every screen.

**The name on the home screen broke mid-word**: "Jabuli / le". No test
would ever have objected, because nothing overflowed. It was simply ugly in
the one place the app most needs to be clear.

The common thread is not "write more tests". It is that **a test asserts
what somebody thought to assert**. All three were found in under an hour of
using the app the way a person would, at a setting the author does not use.

## N7 had one gap, and it was the worst one

Everything in this app already survived being killed, because everything is
written the moment it changes — the family, who this phone belongs to,
whether reminders are on, saved entries.

Everything except a journal entry being typed, which lived in a
`TextEditingController` and nowhere else. Of all the state in this app it
is the only piece that is irreplaceable: a rota can be rebuilt from four
names, and a half-finished prayer cannot be rebuilt from anything.

Drafts are now written on a 600ms debounce and on backgrounding. Verified
the way the requirement is written: typed, `simctl terminate`, relaunched,
text came back.

## Not deferred

#21's criteria allow findings to be filed as defects rather than fixed.
Nothing was. Every finding above is fixed in #61 or #62, so this pass adds
no new defects to the backlog — the two open ones (#30, #32) predate it.

## Still open

- **Firestore sync is unwired.** `RemoteFamilySource` has no
  implementation, so the four phones still do not see each other. ADR-012
  was written for a merge nothing currently calls. Still a decision for the
  owner; it does not fit in Days 14–15.
- The rules need deploying: `firebase deploy --only firestore:rules`.
- The two `Mashibini.Prayer` app registrations in the console are unusable
  and should be deleted.

## Tomorrow

Day 14 — release. Release branch, version bump, changelog, tag v1.0.0.
