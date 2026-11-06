# Day 22 — The restyle

**Date:** 2026-11-06 · **Phase:** 8, v1.1 front end · **Roles on point:** Developer

## Planned

> Every screen onto the new design system. This Week regains its focus —
> likely the verse moving to its own card and the version moving into
> Settings. Confirmation and undo for destructive-feeling actions. The empty
> states get a next step instead of a full stop.

Two of those were already done and the plan did not know it: the verse has
had its own card since Day 10, and the version moved to Settings on Day 19.
So the day was the spacing, the undo, and the empty states.

## Delivered

- Every gap and every padding in `lib/src/presentation` on the scale
- `Space.fabClearance`, the one measurement that is not a step
- A snack bar with Undo when a week is passed over
- Three empty states that offer a next step
- `spacing_test.dart`, which fails if a bare number comes back
- 583 tests, up from 573.

## The design system nothing enforced

Day 17 wrote `Space` — seven steps, with a doc comment naming the thirteen
distinct `SizedBox` heights it was replacing. Then Days 18 to 21 built new
screens on it and left the old ones alone, because nothing stopped them.

The count on the morning of Day 22: **28 raw `SizedBox` heights against 19
tokenised**, and seven files on hand-picked `EdgeInsets`. The scale had been
adopted by the newest quarter of the app.

Snapping them was mechanical except where it was not, and the exceptions are
the interesting part.

### Three numbers that did not become tokens

**`Space.fabClearance = 96`** — bottom room for the Write button to float
over the journal. Not a decision about rhythm: it is the height of a 56pt
button plus its margin. Rounding it to 48 would put the last entry under the
button that writes the next one. Named, with the reason in the doc comment,
because the scale's own rule is that an off-scale number means a layout
nobody has thought about — and this one has been. The name is what says so.

**The verse's rule, 28 × 2.** A drawn line whose dimensions are what it looks
like. Turning it into two tokens that happen to sit near 28 and 2 would be
treating a shape as a gap.

**`0`.** `fromLTRB(Space.lg, 0, Space.lg, Space.sm)` means no padding on that
side. There is no token for nothing, and `Space.none` would be a second word
for one that exists. The guard flagged four of these on its first run, which
is how the exception came to be written down instead of assumed.

### Two gaps that were lying

Snapping the numbers also fixed two things that had never been noticed:

- **This Week was inset 20, everything else 16.** Each tab used its own
  horizontal inset — 8, 18, 20 — so nothing lined up between tabs, which is
  precisely where it shows, because switching tabs puts the two side by side
  in memory. All of them use `Space.gutter` now.
- **The verse sat 8 further in than the card above it**, so its rule did not
  quite align with the card's edge. Removed.

Neither was a bug anybody would report. Both are the kind of thing that makes
an app feel slightly unresolved without anybody being able to say why.

## Undo instead of confirmation

The plan asked for "confirmation and undo" on skipping a week. Skipping was
already reversible — the row keeps an Undo button, and Day 13 added a spoken
announcement — so the gap was narrower and odder than the plan thought:

**The app told somebody who could not see the list, and said nothing to
somebody who could.** `SemanticsService.sendAnnouncement` has carried
"Sisi's turn was passed over" to screen readers since Day 13. A sighted
person tapped Skip and the list rearranged in silence.

So: a snack bar, carrying **the same string** that is spoken, with Undo in
it. One argument to `_edit` feeds both, which is deliberate — Day 19 shipped
a share sheet whose subject read "2026-11-04" over a body reading "Wednesday,
4 November", two strings each correct and disagreeing with each other. Two
ways of telling somebody their week changed hands is the same trap.

**And no confirmation dialog.** A dialog in front of every skip is a toll
paid on each correct tap to catch the rare wrong one. Undo charges nothing
until somebody needs it. The plan said "confirmation and undo"; for a
reversible action, undo alone is the kinder half, and the dialog would have
been the half that gets switched off in somebody's head after a week.

The snack bar's Undo and the row's Undo call one method, so they cannot come
to mean different things.

## Empty states that stopped

Three of five were already fine — This Week's "No rota yet" has had a button
since Day 8. The other two were saying true things and stopping:

**The weeks ahead** said *"The rota has not started yet, so there are no
weeks to show."* True. It also left out the only fact worth knowing, and the
screen was holding it: `RotaEngine.startedOn`. This Week has named that date
since Day 14. Now this one does too.

**The journal** said *"Nothing written yet"* and described where entries
live, leaving somebody to work out that the thing which fills the screen is
the button floating over the sentence they are reading. It has a button now.

**The Family tab** pointed nowhere, because that screen cannot set up a rota
— it has no route to. It names the tab that can.

## A scale needs a bailiff

`spacing_test.dart` reads the source of the presentation layer and fails on a
`SizedBox` with a bare number or an `EdgeInsets` with one. Without it, Day 22
is a tidy-up that lasts until the next screen.

It is narrow on purpose. A hexagon's radius, an icon's size, a drawn rule —
those are the dimensions of things, and `Space` is about the rhythm between
them. The two patterns it does police are always rhythm: a `SizedBox` with
one axis set is a gap, and padding is padding.

**And it has a test that checks it can fail.** Day 21's lesson applied on the
way in rather than afterwards: two of three assertions written for #111
could not fail, and nothing but breaking them on purpose found that out. So
the last test in the file feeds the matchers a known-bad line and a known-good
one and asserts both verdicts. A guard whose regex has quietly stopped
matching reports a clean codebase forever.

## What this day did not do

**#111 is withdrawn, not fixed.** It was filed on Day 21 claiming the tab
labels were cut off on most phones. Running the app to answer "how is it
now?" produced a screenshot in which all five render in full — and the
figures behind the issue turned out to be measured in Flutter's fixed-width
test font, where `iiiiiiii` and `MMMMMMMM` are the same width.

The restyle was the obvious place to fix a label defect. There was no label
defect. What there was: two ADRs, two day logs, a PR body and a test all
asserting one, written over two days, from a number nobody questioned.

**Touch targets are not measured.** `Touch.minimum` exists and its doc
comment says "Day 22's accessibility pass will measure against" it. That pass
is Day 23, and this is a note so the sentence is not left pointing at a day
that went past without doing it.

## Tomorrow

Day 23: the icon, the full accessibility re-pass including touch targets, and
a release — the first since v1.4.0, carrying Days 19 to 22.
