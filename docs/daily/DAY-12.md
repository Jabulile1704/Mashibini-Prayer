# Day 12 — Handover reminders

**Date:** 2026-10-29 · **Phase:** 4, implementation · **Roles on point:** Developer, QA

## Planned

Remind the incoming leader before their week starts (#15, R5.1).

## Delivered

| # | What | Where |
|:--|:--|:--|
| #59 | `ReminderPlan`, the `Reminders` seam, `LocalReminders`, the Reminders screen, per-device opt-in | merged to `develop` |

325 tests, analyzer clean. 30 of them new.

## R5.1 as written cannot be built, and that was known before today

The requirement reads "the incoming leader is told their week starts
tomorrow". The obvious reading — the app tells them — needs something that
sends a push, and ADR-010 established there is nothing here that can:
Cloud Messaging needs a sender in a trusted environment, and the Spark plan
has no Cloud Functions to put one in.

So the requirement was delivered in the only form the plan allows: **each
phone reminds its own user**. No device reaches another.

This was not discovered today. Day 11 wrote it down, which meant today was
spent building the achievable half rather than finding out halfway through
that the other half was impossible. **The ADR paid for itself the day after
it was written.**

What it costs: the family cannot be nudged collectively. Somebody who never
opens the app and never switches reminders on will not be told anything.
That is a real gap, it is in REQUIREMENTS.md against R5.1, and closing it
needs either a paid plan or a device that volunteers to be the sender —
neither of which is a decision for an implementation day.

## The planner knows nothing about notifications

`ReminderPlan.forDevice` takes the family, who holds this phone, and the
time. It returns a list. It schedules nothing.

Everything interesting is therefore testable without a plugin and without
waiting until Saturday evening: that a moment already passed is skipped,
that the horizon fills with *this person's* turns rather than the next eight
turnovers of anybody's, that re-planning produces byte-identical ids so
re-scheduling replaces instead of stacking duplicates.

`LocalReminders` is the only file that imports the plugin. `FakeReminders`
stands in for it, which is the thing that makes R5.1's second criterion
provable at all: **an install nobody has asked must stay silent**, and
silence is only assertable against a double.

## The bug the simulator found, which the tests could not

Everything was green. 320 tests, analyzer clean, every acceptance criterion
covered. On the simulator the switch went on, iOS asked for permission, the
permission was granted — and "Coming up" was empty.

Setup asks "which one are you?" and marks it optional. Until today that
question only chose between saying *your week* and saying a name, so leaving
it blank cost nothing. Reminders made it load-bearing: a phone that does not
know whose it is cannot know which weeks to ring for. And there was no
second place to answer it — the only route was rebuilding the rota from
setup.

**The tests could not have caught this.** Every one of them set `youAre`
first, because every one of them was written by somebody who knew the field
existed. The test for the unset case asserted that nothing was scheduled,
which is correct behaviour and completely useless as a warning: it described
the dead end instead of objecting to it.

Fixed in the same PR rather than filed for Day 13. A reminders feature that
cannot be armed is not R5.1 delivered, and shipping it to say the story was
done would have been scoring the plan instead of the app.

### The smaller lesson

A field that is optional is optional *for the features that exist when it is
written*. Adding a feature that depends on it silently promotes it, and
nothing in the type system or the test suite notices. Worth looking at the
other optional settings on Day 13 before something else quietly starts
depending on one.

## Two details worth recording

**Reminders are scheduled inexactly.** An exact alarm on Android needs a
permission intended for alarm clocks and calendars. "The evening is here"
does not need to land on the second, and asking for that permission to
deliver it would be out of proportion.

**`timezone` is a dependency on purpose.** "The evening before, at 19:00" is
a wall-clock time, not an instant. Scheduled as UTC it would drift when the
clocks change; 19:00 was chosen for being a reasonable hour in the house, so
it has to stay 19:00 in the house.

## Still open

- **Firestore sync is unwired.** `RemoteFamilySource` has no implementation,
  so the four phones still do not see each other. Flagged for a decision —
  it does not fit in Days 13–15 as planned.
- The rules need deploying: `firebase deploy --only firestore:rules`.
- The two `Mashibini.Prayer` app registrations in the console are unusable
  and should be deleted.

## Tomorrow

Day 13 — hardening. Skip a turn (R1.4), offline and empty states,
accessibility, and a look at the other optional settings per the lesson
above.
