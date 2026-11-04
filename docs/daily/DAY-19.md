# Day 19 — Settings

**Date:** 2026-11-04 · **Phase:** 8, v1.1 front end · **Roles on point:** Developer

## Planned

From [PLAN-v1.1-UX.md](../PLAN-v1.1-UX.md):

> The tab that gives all the bolted-on pieces a home: which one are you,
> reminders, turnover day, light/dark/system, about and version. Removes the
> duplicated "which one are you?" from the Reminders screen, and folds that
> screen into a settings row.

Five of the six shipped. The sixth turned out not to be a settings row at
all, which is the day's main finding.

## Delivered

| # | What | Where |
|:--|:--|:--|
| — | Which one are you, appearance, reminders folded in, About | PR #101 |
| #100 | Opened: changing the turnover day, with ADR-019 deciding how | open |

455 tests, analyzer clean. 29 new, one screen and its test file deleted.

## The defect this screen exists to fix

"Which one are you?" could be answered **once, wrongly, forever.**

Setup asked it optionally. Day 12 made it load-bearing for reminders and had
nowhere to put it, so the question was duplicated onto the Reminders screen
— behind `if (family != null && youAre == null)`. It showed itself only
while the answer was missing and vanished as soon as one was given.

So a phone that thought it belonged to Mama rang for Mama's weeks, and there
was no screen in the app that would change it. The only cure was *Start the
rota again*, which replaces the whole family to fix a one-word mistake.

The row that fixes it is three lines of list tile. The reason it took
nineteen days is that nobody had looked at the question from the position of
somebody who had already answered it.

### And the half of it that does not show

Changing the name has to **re-plan the reminders**. Saving it without
rescheduling leaves the phone holding notifications for whoever it used to
think it was — correct in storage, wrong in the world, and silent about it.
That is the kind of bug that gets reported as "the app pinged me for Sisi's
week" six weeks later, if at all.

The Reminders screen did this and the row inherited the obligation along with
the question. There is a test for it that asserts the *date* moved, not just
that something was scheduled.

## The turnover day is not a setting (ADR-019)

The plan listed it next to the other three. It is a different kind of thing,
and the probe that proved it was run before a line of the row was written:

```
Invalid argument (cycle.effectiveFrom): must fall on the turnover weekday (1),
but c1 starts on a weekday 7: "2026-10-18"
  package:…/rota_engine.dart 42:9   new RotaEngine
  package:…/rota_engine.dart 57:50  new RotaEngine.forFamily
```

`Family.turnoverWeekday` is one field and `Week.startOf` uses it for every
week boundary the rota has ever had. Every cycle is anchored to a turnover
day, and `RotaEngine`'s constructor refuses a family whose cycles no longer
sit on it. `RotaEngine.forFamily` is called from `ThisWeekScreen.build`.

**A row that wrote the field would have thrown on the next frame of the home
screen, and every frame after it** — for a family whose rota had been fine,
with no route back except reinstalling and losing the journal.

ADR-019 decides the real design: the turnover weekday moves onto `Cycle`, so
changing it writes a new epoch the way adding a person already does, and past
weeks keep their boundaries. #100 builds it alongside #74's family editor,
which needs the same machinery.

What shipped instead is the day shown, not tappable, with *Start the rota
again* directly beneath it saying what it replaces. The app displayed the
turnover day **nowhere at all** before today — answerable in setup, then
invisible.

### This one was caught by reading, not by using

Four times in this project the thing tests could not see was found by holding
the phone. This is the first time the landmine was found by reading the
invariant before writing against it, and it is worth noticing which habit
caught it: the engine's constructor documents what it refuses, in a throw
with a message that names the field. That message is the only reason the
probe took two minutes instead of a bug report in December.

## Folding the Reminders screen in

A whole screen, behind a chevron, behind an unlabelled bell before that,
holding one switch and a three-item list. It is now a `SwitchListTile` and a
sentence.

The "Coming up" list went from three reminders to one, as the switch's own
subtitle: *Next: the evening before Sunday, 25 October 2026.* Its purpose was
to let somebody check that the phone agrees with them about whose week is
next, and one answers that. 170 lines and a navigation step for the other
two was not a good trade.

`reminders_screen.dart` and its test file are deleted rather than left
unreachable. `FamilyEditor` has been built and unreachable since Day 7 and it
is still the largest gap in the app (#74); one of those in the tree is
enough.

## Appearance, and the flash that did not happen

`watchAppearance()` yields its first value asynchronously. A stream alone
would therefore paint one frame in the wrong theme — and because the splash
is the first thing on screen, a phone set to light with the app set to dark
would **flash white and then go dark on every cold start**.

So `main()` reads it before `runApp` and passes it as `initialData`. One
await, no flash. There is a test that asserts the theme on the very first
`pump()`, before anything settles, because that is the frame the bug lives
in.

The stored value is a word rather than an index. An index is read against
whatever order the enum happens to be declared in, so inserting a fourth
option later would silently change what every phone had chosen. An
unrecognised word falls back to following the phone — that is what an older
install reads after a newer build has written something it has never heard
of, and it has to be an *answer* rather than a throw, because this is read
before the first frame.

## Two things cleaned up on the way past

**`ThisWeekScreen` was still being handed `journal`, `reminders` and
`appVersion`.** Day 18 moved everything that used them out and left the
parameters behind. The analyzer does not flag an unused public field, so
three dependencies the screen no longer has would have sat in the
constructor misleading whoever read it next.

**Settings was not in the accessibility sweep.** Day 18 created the screen
and did not add it. It is in now, with About, at 1.0×, 2.0× and 3.1× in both
the stored and the empty state — 36 pumps where there were 30. The
[plan's own risk list](../PLAN-v1.1-UX.md) named this exact failure mode:
*"the accessibility work is the thing most likely to be quietly undone."*
It was being undone by addition rather than by edit, which is harder to
notice.

## Tests that failed for the right reason

Four shell tests broke, and not because the code was wrong: Settings is now
long enough to scroll, and a `ListView` does not build what is below the
fold. A finder for an off-screen row reports it **missing**, which looks
identical to a row that is not there.

The fix is a `reveal` helper that scrolls the right `Scrollable` — the right
one mattering because `IndexedStack` builds all four tabs, so there are four
in the tree at once.

Worth writing down because the failure message was misleading in a specific,
repeatable way. "Found 0 widgets" on a scrolling screen means *look below the
fold* before it means *look at the code*.

## Tomorrow

Day 20: #74, the family editor — add and remove people from Settings,
calling the `FamilyEditor` that has existed since Day 7. #100 belongs with
it, since changing the turnover day needs the same new-epoch machinery and
the same screen.
