# ADR-019 — The turnover day is an epoch, not a setting

**Status:** Accepted · **Date:** 2026-11-04 · **Deciders:** Owner

## Context

[PLAN-v1.1-UX.md](../PLAN-v1.1-UX.md) lists the turnover day as one of Day
19's settings rows, next to "which one are you" and light/dark/system:

> ### Day 19 — Settings
> The tab that gives all the bolted-on pieces a home: which one are you,
> reminders, turnover day, light/dark/system, about and version.

The other three are rows. This one is not, and the plan did not know that
when it was written.

## What a row would have done

`Family.turnoverWeekday` is a single field, and `Week.startOf` uses it to
find *every* week boundary the rota has ever had. Changing it does not
change the next week; it re-slices all of them, backwards as well as
forwards.

`RotaEngine` already refuses that, in its constructor:

```dart
if (cycle.effectiveFrom.weekday != turnoverWeekday) {
  throw ArgumentError.value(…);
}
```

Every cycle is anchored to a turnover day. Move the family's turnover day
and the anchors no longer sit on it. The probe, run before writing any of
Day 19's screen:

```
Invalid argument (cycle.effectiveFrom): must fall on the turnover weekday (1),
but c1 starts on a weekday 7: "2026-10-18"
  package:…/rota_engine.dart 42:9   new RotaEngine
  package:…/rota_engine.dart 57:50  new RotaEngine.forFamily
```

`RotaEngine.forFamily` is called in `ThisWeekScreen.build`. So a settings
row that wrote the new weekday and popped back would have **thrown on the
next frame of the home screen, and on every frame after it** — for a family
whose rota was previously fine, with no way back except reinstalling.

This is the kind of defect the project keeps finding by using the app rather
than by testing it. It was found by testing this time, which is progress,
and only because the engine's invariant was read before the row was written.

## Decision

**A changed turnover day writes a new cycle epoch, and the turnover weekday
moves onto `Cycle`.**

The mechanism already exists. Adding or removing a member writes a new epoch
effective from the next turnover, and dates before it keep resolving against
the epoch that was in force (ADR-002, R2.3). Changing the day the week turns
over is the same kind of change, and it gets the same treatment.

```dart
class Cycle {
  final CalendarDate effectiveFrom;
  final List<String> order;
  final int turnoverWeekday;   // new
}
```

`Family.turnoverWeekday` stays, as *the current* one — what a new epoch
inherits and what the setup screen writes. The engine resolves a date by
walking cycles newest-first, computing each candidate's week start with
**that cycle's own** weekday, and taking the latest cycle whose
`effectiveFrom` is on or before it.

### Why per-cycle rather than rewriting the anchors

The alternative is to shift every existing cycle's `effectiveFrom` to the
nearest day of the new weekday. It needs no schema change and it is wrong:
past week boundaries move by up to six days, so a week that has already
happened can change whose it was. R2.3 exists to prevent exactly that, and a
journal entry written on a Sunday would find itself in a different person's
week.

Per-cycle costs a schema version and a migration. Each old cycle inherits
the family's weekday, which is what it already meant, so the migration is
exact rather than best-effort.

### The week in progress keeps its leader

Effective from the first day of the new weekday that falls **after** the
current week ends. Not during it: somebody's week should not be cut short or
extended because a day was changed on a Wednesday — the same rule the member
edits already follow.

## What Day 19 ships instead

The row exists and shows the current turnover day, because until now the app
displayed it nowhere at all — it was answerable only in setup and then
invisible. It is **not tappable**, and the row directly beneath it is "Start
the rota again", which does change the turnover day and says what it
replaces.

A disabled row with a working route under it is honest. A row that writes the
field and bricks the home screen is not, and shipping one in order to tick
off a plan written nine days ago would be the worse mistake.

Implementation is [#100](https://github.com/Jabulile1704/Mashibini-Prayer/issues/100),
scheduled with #74's family editor on Day 20 — which needs the same
new-epoch machinery, so the two belong together.

## Consequences

**Day 19's deliverable is narrower than the plan's**, and said so rather
than quietly shipping three of four rows.

**The schema gains a version.** `Family.currentSchemaVersion` goes to 2 when
#100 lands, with a migration test for a v1 family read by the new build —
the first real migration this app has had, which is a thing worth doing once
carefully rather than four times badly.

**`RotaEngine.turnsFrom` has to stop stepping by seven.** It advances a
cursor by seven days from one week start to the next. Across an epoch
boundary where the weekday changed, that lands off the grid. It must step to
`turn.weekEnd.addDays(1)` and let `turnOn` normalise, which it already does.
Noted here because it is the one place the change is not local.
