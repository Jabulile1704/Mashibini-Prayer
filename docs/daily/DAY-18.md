# Day 18 — The navigation shell and the splash

**Date:** 2026-11-03 · **Phase:** 8, v1.1 front end · **Roles on point:** Developer

## Planned

Bottom navigation, the four tabs of ADR-016, screens moved in unchanged, and
a splash that transitions rather than cuts. Expect test maintenance.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #96 | `HomeShell`, `SettingsScreen`, `SplashGate`, the mark's geometry fixed | merged |

431 tests, analyzer clean. 13 new.

## The fix for the icons was to stop having icons

Day 13 found the three app-bar icons had no screen-reader names and gave
them some. That was correct and it was a patch: a name does not make an
unlabelled icon discoverable to somebody *looking* at the screen, and
top-right is the hardest place on a phone to reach one-handed.

Four tabs with visible labels is the actual fix. The accessibility test that
checked those icons had names now asserts **there are no icon buttons
left**, which is a better thing to assert.

## Settings was a relocation, not an invention

Three things that had no home now have one: the reminders switch that was a
whole screen behind a bell, the "start again" control bolted into the app
bar on Day 17, and the version line that went on This Week on Day 14 only
because there was nowhere else to put it.

That is the whole of ADR-016's argument, visible: Day 8's "this screen
answers one question" was never abandoned — there was simply nowhere else
for anything to go.

## The mark was wrong, and the comment said it was right

The painter's own comment:

> small enough that they do not touch — a comb whose cells overlap stops
> being countable, which is the whole job.

At four cells they overlapped by about a third. The spacing was a flat
fraction of the width, picked by eye on Day 17 and never checked.

Solved rather than nudged: adjacent centres on the ring sit
`2·orbit·sin(π/n)` apart and clear at `2·radius`, so
`radius = (size/2)/(1 + 1/sin(π/n))`. Verified across two to six cells
before writing it.

**No test could have caught this.** Nothing in 431 tests measures whether a
picture is a tangle. It was found by looking at the mark at 112px on a
splash screen — which is the fourth time in this project that the thing
tests cannot see was found by using the app.

A comment that asserts a property the code does not have is worse than no
comment. It is the reason nobody re-checked.

## Two things flutter_test teaches you once

Both written into the tests that needed them rather than left as folklore.

**`pumpAndSettle` pumps only while frames are scheduled.** A static splash
schedules none, so its 650ms timer never fires and the gate never opens. All
four splash tests failed on this while the code was correct — which is worth
remembering next time a test fails: the code is not automatically the
suspect.

**A pending timer at teardown is a failure.** Rightly: a widget that leaves
one behind keeps working after it is gone.

## One gotcha that cost a confusing screenshot

The simulator caches the **native** launch image per install. After fixing
the mark's geometry I cold-started the app and photographed the old,
overlapping version — not because the fix had failed, but because iOS was
showing a cached PNG. The card behind it already had the new geometry.

Worth knowing, because the native launch image and the Flutter splash have
to match exactly or the handover flashes. When the mark changes, both change
and the app needs reinstalling before you can trust what you see.

## Tomorrow

Day 19 — Settings properly: which one are you, the turnover day, light,
dark and system. The screen now exists for them to arrive into.
