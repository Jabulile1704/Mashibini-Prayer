# Day 20 — The turnover day moves onto the cycle

**Date:** 2026-11-05 · **Phase:** 8, v1.1 front end · **Roles on point:** Developer

## Planned

The plan had Day 20 as "change the family (#74), and the turnover day
(#100)" — both in one day, both behind one screen.

Costing it first said otherwise. #74 is a screen over an editor that has been
finished since Day 7. #100 changes what a week *is*, and the engine, the
editor, the merge and the stored document all have an opinion about that. So
the day was split: today is #100's domain, with **nothing visible shipping**,
and the screen for both is Day 21.

Splitting a planned day is worth more scrutiny than merging two, because it
is the move that quietly turns three remaining days into four. It was the
right call for one reason: a screen built on top of a half-settled week
boundary would have been rewritten the moment the boundary settled.

## Delivered

- `Cycle.turnoverWeekday`, derived from its own anchor
- `Family.turnoverWeekday` and `Family.latestCycle`, derived from the cycles
- `RotaEngine` resolving epochs newest-first, with `turnoverWeekdayOn`,
  `weekStartOn` and `cycleFor`
- `Turn.weekEnd` cut short where the next epoch begins first
- `RotaEngine.turnsFrom` stepping by the week it just measured, not by seven
- `FamilyEditor.changeTurnoverDay`
- `CycleReason.turnoverDayChanged`
- `Week.onOrAfter`
- Schema **v2**, migrating on read, with a v1.4.0 document in the test suite
- Net 41 more tests — 477 → 518 — with two deleted for being tautologies

Not delivered, on purpose: any way for a person to use it. That is Day 21.

## The field that was already there

ADR-019 decided the turnover day belongs to the cycle, and specified how:

```dart
class Cycle {
  final CalendarDate effectiveFrom;
  final int turnoverWeekday;   // new
}
```

Before writing it, the invariant it was meant to satisfy got read one more
time — the one whose violation produced ADR-019's probe crash:

```dart
if (cycle.effectiveFrom.weekday != turnoverWeekday) throw …
```

A cycle's `effectiveFrom` **must** fall on a turnover day. So the weekday of
`effectiveFrom` *is* the epoch's turnover day, and has been since Day 2. The
field was a second copy of something already in the document.

```dart
int get turnoverWeekday => effectiveFrom.weekday;
```

That one line removed the stored field, the pair that could disagree, the
migration to populate one from the other, and the engine's check — which now
compares a value with itself. The same treatment suited
`Family.turnoverWeekday`: a getter over the latest epoch rather than a scalar
kept in step by hand. It dropped an argument from four constructors and a
line from `FamilyMerge`, where picking the day from the "newer" side could
contradict the epochs it was supposed to describe. Derived, it is commutative
for free.

**#103 was a check that could not fail and had to be repaired. This was a
check that could not fail and had to be deleted.** Telling those apart is
the whole of it: one was guarding something real with a broken instrument,
the other was guarding a tautology.

## A migration that does nothing, and still earned its version

The document is byte-for-byte what v1.4.0 wrote. No field added, none
removed, none renamed. The v1 → v2 migration is a no-op.

It is still a version, because the *meaning* changed in one direction only. A
v2 family may hold epochs sitting on different weekdays. Hand one to a v1
build and it goes to an engine that checks every cycle against a single
weekday and throws — on every frame of the home screen, with no way back but
reinstalling. That is precisely what `schemaVersion` is for: the marker makes
that build decline the document instead.

Three things make "it does nothing" a measurement rather than a hope:

- A **literal v1.4.0 document** sits in `family_json_test.dart` as a string,
  not as `toMap` output, so the test cannot drift along with the writer.
- It is compared against the same family built in the new shape, for **every
  day of the following year** — not for one date.
- Migration happens **on read**, so a phone that opens the app and changes
  nothing is upgraded too. There is no population of documents quietly stuck
  at v1 waiting for the migration after next to find them.

A fourth fell out of it. v1 never checked `turnoverWeekday` against its
cycles; the engine did, at every call, which made a document where they
disagreed unopenable. Ignoring the field makes such a document readable
again. The migration removed a crash class it was not aimed at.

## The calendar does not divide

Everything above was tidying. This is the part that needed a decision.

Move the handover from Sunday to Wednesday and the weeks no longer line up.
The first Wednesday after the current week ends is one to six days after it,
so something has to give. Decided on Tuesday 3 November, with Sunday weeks
from 18 October:

```
Sun  1 – Sat  7 Nov   Mama       the week it is decided in, untouched
Sun  8 – Tue 10 Nov   Tata       three days
Wed 11 – Tue 17 Nov   Jabulile   the new epoch
```

There is no version without a short interval. The only alternative to a short
week is a **gap with nobody leading**, which is worse — the app's one job is
to answer whose week it is.

**Who leads the short week, and what follows it?** Two options:

- Carry its leader into the new epoch's first full week. This is "whoever was
  already going to lead it", the sentence the member edits follow, and ADR-019
  repeated it. It gives Tata **13 days**.
- Treat the short week as a turn taken and start the new epoch with the next
  person. Tata gets **three days**.

The second. Three days is a week a family absorbs without noticing; a
fortnight is one they would mention at supper. So ADR-019's own sentence does
not survive contact with a weekday change, and the implementation note says
so rather than leaving the ADR looking prescient.

**The short week is reported short.** `Turn.weekEnd` is cut at the next
epoch's start. Without that, Tuesday 10 November was the last day of Tata's
Sunday week *and* inside Jabulile's Wednesday one — one date in two people's
weeks, which the Schedule screen would have printed. The test that holds it
is a property, not an example: across ninety days spanning the change, every
single date resolves to exactly one turn and is inside it.

## Two things that would have gone wrong quietly

**`turnsFrom` stepped by seven days.** ADR-019 predicted this one. From
Sunday 8 November, seven days lands on Sunday 15 — inside the new epoch's
*second* week, stepping over the short one entirely and listing Jabulile
twice. It now steps to the day after the turn it just measured, which is the
next turn's first day whatever its length.

**A second change would have landed before the first.** Change the day on
Tuesday, change your mind on Wednesday, and "the first new day after the
current week ends" puts the second epoch *earlier* than the first. The engine
resolves the first one anyway and the family sees nothing happen. Epochs are
appended and never replaced — one deleted on a phone comes back from the
other's copy (ADR-012) — so the rule is: after the current week **and** after
every epoch already written. Two changes in a week cost two short weeks.
They do not cost correctness.

Neither was found by using the app, because there is nothing to use yet. Both
were found by asking what the second call does after the first — which is the
question that the member edits never had to answer, because adding two people
in a day writes two epochs on the same date and the tie-break handles it.

## Reminders needed no telling

`ReminderPlan` reads turn boundaries off the engine rather than stepping
weeks itself, so a moved turnover day moves the reminders with it: the
evening before a Wednesday handover is a Tuesday. That was already true and
is now tested, because a notification that kept arriving on the old evening
is not the sort of thing anybody reports. They just stop trusting it.

The short week is reminded about too, and only once. Two reminders sharing an
id would replace each other, so the ids are asserted distinct.

## What is still a lie on screen

Settings still shows the turnover day as an untappable row. It now reads the
derived value, which during a pending change is the day the family *chose*
rather than the one in force this week — correct for a row whose job is to
say what was chosen, and incomplete, because it does not say when it starts.
Day 21 owns that.

## Tomorrow

Day 21: the family editor reaches Settings (#74), and the turnover day row
becomes real. Both have to say **when** a change takes effect, because
neither takes effect today, and the turnover row has to own up to the short
week.
