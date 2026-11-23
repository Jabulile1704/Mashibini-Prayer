# Day 37 — The trigger was the screen, and the screen stopped being the only one

**Date:** 2026-11-23 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, QA

## Planned

Re-run the release job. The owner said the secret was in.

## Delivered

- **#160** — reminders follow the rota rather than the screen that edits it
- `KeepRemindersInStep`, 7 tests, broken on purpose and watched to fail
- R5.1's first criterion marked broken-and-fixed, with the three days named
- Two entries in the retrospective, one of them about my own branch
- 875 tests, up from 868

## The release is still stuck, and it is not stuck on judgement

Re-run anyway, because being told twice that a secret is present and
answering with an API read a third time is not a conversation. The run
reached the same step:

```text
FAILED AT: The service account is present
```

Everything before it passed, including the **34 rules tests against the
emulator on the tagged commit**. So the runner reads an empty variable too;
this is not my reading of an API being stale.

`gh secret set FIREBASE_SERVICE_ACCOUNT --repo … < key.json` remains the
whole of the remaining work, and it is the owner's to run — that file is a
live credential and should go from their disk to GitHub without passing
through here.

## So the day went looking at what v2.2.0 changed

`RescheduleReminders` is called from exactly two places:

```text
lib/src/presentation/screens/settings_screen.dart:283
lib/src/presentation/screens/family_members_screen.dart:51
```

Both screens. Both running when **somebody on this phone edits the rota**.

For twenty-five days that was the only way a rota could change, so a screen
was the right place. v2.2.0 gave it three more, none of which involve a
screen:

| | |
|:--|:--|
| a merge arrives | the cycle, the turnover day or a skip changes under a phone nobody is holding |
| a reinstalled phone signs in | `FindMyFamily` attaches and the family appears whole |
| a phone joins another family | `JoinAFamily` clears `youAre` and saves somebody else's rota |

So R5.1's first criterion — *the incoming leader is told their week starts
tomorrow* — **has been false on every phone except the one making the change
since Friday.** The third row is the ugliest: a notification about a rota
the phone has left, naming a week that belongs to nobody.

## This one is not a check that failed

There was no check, and there had been no need for one. The invariant held
**by construction**: only one thing could break it, and that thing also
fixed it. Then a second thing arrived.

| | What changed | What quietly stopped holding |
|:--|:--|:--|
| Day 37 | a second way for the rota to change | every invariant maintained at the first way |

It is the sibling of Day 34. There, a *value* stopped being right when its
field acquired a second job. Here, a *reaction* stopped being reachable when
its cause acquired a twin.

So the question worth asking after shipping something like sync is not "what
did I break" — nothing broke, everything still compiles and passes — but
**"what used to be true because only one thing could change this?"**

## Why nothing caught it

Every test triggers the reschedule the way a screen does.
`reminder_plan_test.dart` is thorough about *what* to schedule given a
family. `settings_screen_test.dart` asserts reminders move when the turnover
day changes **on that screen**.

Nothing asked what happens when the family changes and no screen was
involved — the same question Day 30 found nobody had asked of the SAS
Function's success path. A suite can be complete about one trigger and
silent about the existence of others.

One detail from writing the tests: `FakeReminders` had no call counter, only
the last plan it was handed. For this defect the count is the whole point —
**the plan can be identical and still have to be re-made** — so asserting on
`scheduled` alone would pass while nothing rescheduled.

## And then I cut the branch from the wrong place

`fix/160` came off `main` rather than `develop`. `main` had been checked out
to push the v2.2.0 tag and I never went back.

So the pull request, against `develop`, would have **reverted yesterday's
work**: the About screen's derived copy and the sweeps' drift guard.

**All seven required checks passed.** Correctly. The branch was internally
consistent and the suite genuinely passed on it — Day 29's finding arriving
on an ordinary feature branch instead of a release: *both sets are
internally coherent; the smaller one is a perfectly good app, it is just not
this one.*

What caught it was a number refusing to add up. The suite said 854;
`develop` had measured 868 the day before. **The first instinct was to
explain the gap away**, and the pull request's original body contains a
sentence written to do exactly that — "854, up from 868 minus the 21
About/sweep tests that moved" — which means nothing and was assembled to
make a number stop being strange.

Measuring instead: a throwaway worktree on `develop`, per-file counts, and a
diff.

| | develop | the branch |
|:--|--:|--:|
| `about_screen_test.dart` | 9 | 4 |
| `accessibility_test.dart` | 77 | 70 |
| `guidelines_test.dart` | 49 | 40 |

Twenty-one tests, exactly yesterday's work. Rebased onto `develop`: 875, and
`git diff origin/develop...HEAD` goes from 260 files to four.

`tool/release.sh` refuses to continue unless `git diff develop` is empty, and
that check exists because of Day 29. Nothing makes it for an ordinary
branch, and `git merge-base --is-ancestor origin/develop HEAD` is one line.

The habit is smaller than a check: **a test count means nothing except
against a baseline measured on the other branch, and when it disagrees,
measure rather than explain.**

## Open

- **The v2.2.0 tag is pushed and the release is unpublished**, waiting on
  one secret. The APKs exist as a run artefact.
- **The journal does not sync**, and the rota now does. A decision about a
  promise (*"neither can we"*), so the owner's.
- **Two real phones.** Still the only test of #75 that counts.
- **#77** — the collective reminder, and the last open story. ADR-010 still
  says the free tier has nowhere to send from.
- **Q5** — nobody fluent has checked the sayings' spelling.
