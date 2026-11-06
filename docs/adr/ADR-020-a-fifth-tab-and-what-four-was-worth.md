# ADR-020 — A fifth tab, and what "four is the ceiling" was worth

**Status:** Accepted · **Date:** 2026-11-05 · **Deciders:** Owner
· **Supersedes:** the "Four is the ceiling" consequence of
[ADR-016](ADR-016-four-tabs-and-what-goes-in-them.md)

## Context

ADR-016 ends with this:

> **Four is the ceiling.** A fifth destination means rethinking, not adding —
> five tabs on a phone is where a bottom bar starts to be a worse answer than
> a menu.

`home_shell_test.dart` held that number, in a test named after the ADR. On
2026-11-05 the owner asked for a Family tab, for a family tree in the app's
honeycomb shape, and asked for it the same day (#109).

So this is a reversal, and it is written down as one. The alternative — adding
the tab and quietly editing the test — is how a decision record stops being
worth reading.

## What the original reasoning turned out to be worth

Three positions were held here in two days, and the third is the one that
stands. The first two are left in the history of this file rather than
smoothed over.

**First draft:** *"five is where a bottom bar starts to be a worse answer"
was a judgement, not a limit* — Material specifies `NavigationBar` for three
to five destinations, so four was inside the range and so is five.

**Second draft:** measured, and the judgement was right — a table of widths
showed three of five labels cut off on a 360pt phone.

**What is actually true:** those widths were measured in a widget test, and
**Flutter's widget tests render with a fixed-width placeholder font.** Every
glyph is a 1em square; `iiiiiiii` and `MMMMMMMM` both measure 98.0. The
figures described the test harness. A walk up the render tree also found no
clipper above the label, so even a genuinely over-wide one would overdraw
into the gap rather than be cut off. #111 is withdrawn.

The app was then run on a 402pt simulator and photographed. **All five
labels render in full**, and `Weeks ahead` wraps to two lines as it should.

So ADR-016's sentence is neither vindicated nor refuted. It was unverifiable
when written, it is still unverified, and the evidence that exists — one
screenshot at one width and one text size — says five tabs are fine there.
What would settle it is a golden test with real fonts, or a look at the app
at the largest accessibility text size. Neither has been done, and that is
the honest state of it.

## Decision

**Five tabs: This week · Weeks ahead · Journal · Family · Settings.**

And **five is the ceiling**, this time for a reason that is not ours to argue
with: `NavigationBar` is specified for three to five. A sixth destination is a
different kind of navigation, not one more icon. That bound is asserted in
`home_shell_test.dart` so it cannot drift upward one request at a time.

### What was checked, and what the checking got wrong

The **shell itself** was added to the accessibility sweep, which had never
built the navigation bar — it pumped screens, and the bar belongs to the
shell. So ADR-016's claim could not have been tested by anything in the
suite at the time it was made. That part was worth doing and stands: no
overflow is thrown at 1.0x, 2.0x or 3.1x, populated or empty, and every
destination announces its name.

Then three assertions were written about label *width*, and the process that
produced them is more instructive than the result.

Two could not fail, which is the
[#103](https://github.com/Jabulile1704/Mashibini-Prayer/issues/103) shape
arriving again:

- `findsOneWidget` on the label — a clipped `Text` keeps its whole string.
- `RenderParagraph.didExceedMaxLines` — always false, because
  `NavigationBar` sets no `maxLines`. Proved by renaming a tab to "Family
  hierarchy and the whole honeycomb of everybody" and watching it pass.

The third, `getMinIntrinsicWidth` against the cell, **could** fail and did —
and was wrong anyway, because **Flutter's widget tests render with a
fixed-width placeholder font**. `iiiiiiii` and `MMMMMMMM` both measure 98.0.
The table it produced described the harness, not any phone, and #111 is
withdrawn.

**Day 21's rule was applied correctly and still produced a wrong answer.**
Breaking an assertion on purpose proves it can fail. It does not prove it
measures the right thing, and nothing in that procedure asks whether the
apparatus is sound. What caught it was running the app and looking at it.

### So: five tabs, and the labels are fine as far as anyone has looked

One screenshot, 402pt, default text size, all five labels complete and
`Weeks ahead` wrapping to two lines. That is the whole of the evidence, and
it is more than ADR-016 had.

A measure-and-hide rule was written on Day 21 and **deliberately not
shipped** — on figures now known to be meaningless, so it would have hidden
the labels on every phone to fix nothing. Not shipping it was right for the
wrong reason, which is worth writing down too.

What would actually settle the question is a golden test with real fonts
loaded, or a look at the app at the largest accessibility text size. Neither
has been done.

### What the tab holds, and what it does not

The ask was "a hierarchy of the family … a pic of each person, name, role …
all within this bee-comb like branch tree hierarchy". The owner said an empty
tab would do for now. It holds a **flat comb** of the people in the rota
instead, because an empty tab reads as broken, and it names the three things
that are missing on the screen itself:

- **No hierarchy.** `cycle.order` is a flat list and `Family.members` has no
  edges between anybody, so there is no branch to draw. That is a schema
  change with its own ADR owing, and the rule it will have to carry is that
  **the tree and the rota are not the same set**: a grandchild belongs in the
  tree without taking a week of prayer.
- **No photographs.** ADR-010's third clause forbids file uploads and stands
  until something supersedes it on paper.
- **No roles.** A `Member` is an id and a display name.

## Consequences

**ADR-016's table is now wrong**, and ADR-016 is not edited to hide that —
this ADR is linked from it. A record that gets quietly corrected is a record
nobody can date.

**Two tests changed because the decisions under them changed**, not because
they were failing inconveniently: the destination count, and the Settings
turnover row that asserted `onTap` was null. Both now carry a comment saying
what they used to assert and why that was right at the time.

**The Family tab will be re-designed, not extended.** A flat comb is not a
tree. When #109's hierarchy lands, the layout is the part that gets thrown
away, which is the cheapest part of this to have built early.

**#111 was opened against this ADR and then withdrawn.** For a day this file
claimed the bar was visibly broken on most phones. It was not, and the cost
of that was two ADRs, two day logs, a PR body and a test all asserting a
defect that did not exist — which is a larger mess than the one-line
reversal this ADR was written for.
