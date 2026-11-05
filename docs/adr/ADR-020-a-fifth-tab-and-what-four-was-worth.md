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

This section said, in its first draft, that *"five is where a bottom bar
starts to be a worse answer" was a judgement, not a limit* — Material
specifies `NavigationBar` for three to five destinations, so four was inside
the range and so is five.

**Then it was measured, and the judgement was right.** The draft is left above
rather than deleted, because being wrong about one's predecessor's reasoning
is the thing this file exists to make visible.

`NavigationBar` gives each label a cell of `width ÷ destinations`. At five
destinations on a 360pt phone that is 72pt, and at ordinary text size
`Journal` needs 88, `Family` 75 and `Settings` 100. Three of the five are cut
off. Material's three-to-five range is about the control, not about whether
English words fit inside it, and ADR-016's sentence was about the words.

It is worse than that, in a direction neither ADR saw: **`Settings` has been
cut off on every phone narrower than about 430pt since Day 18**, with four
tabs, at the default text size, through four releases. So the fifth tab did
not introduce this. It made a shipped defect three times larger, and is what
finally found it ([#111](https://github.com/Jabulile1704/Mashibini-Prayer/issues/111)).

**The reach argument does not apply.** ADR-016's real complaint was
discoverability: three destinations were icon buttons in the top-right of an
app bar, the hardest place to reach one-handed and the easiest to miss. A
fifth *labelled* destination in a bottom bar is not that problem again. It is
the same fix, applied once more.

**The thing actually at risk was never the count.** It was width. Five visible
labels across a 360pt phone at the largest text setting either platform
offers is 72pt each, and this app's last four accessibility defects were all
found at the largest text size — one of them a row at 2.42:1 contrast that the
automated sweep had passed (Day 19).

## Decision

**Five tabs: This week · Weeks ahead · Journal · Family · Settings.**

And **five is the ceiling**, this time for a reason that is not ours to argue
with: `NavigationBar` is specified for three to five. A sixth destination is a
different kind of navigation, not one more icon. That bound is asserted in
`home_shell_test.dart` so it cannot drift upward one request at a time.

### It was not accepted on the reasoning alone

The width risk was checked before this was written, because ADR-016's mistake
was asserting a thing about phones without measuring it. Checking it is what
turned this ADR from a reversal into a reversal plus a defect report:

- The **shell itself** was added to the accessibility sweep. Nothing in that
  sweep had ever built the navigation bar — it pumped screens, and the bar
  belongs to the shell. So the claim ADR-016 made could not have been tested
  by anything in the suite at the time it was made.
- All five labels are asserted present in the bar at **3.1x on a 360pt
  phone**, which is iOS AX5 on a small handset.
- No overflow is thrown at 1.0x, 2.0x or 3.1x, with a family stored and with
  nothing stored.

Two of the three assertions written for it **could not fail**, which is the
[#103](https://github.com/Jabulile1704/Mashibini-Prayer/issues/103) shape
arriving for the third time:

- `findsOneWidget` on the label passes on "Settin" — the widget keeps its
  whole string whatever is painted.
- `RenderParagraph.didExceedMaxLines` is always false, because
  `NavigationBar` sets no `maxLines` and clips instead. Proved by renaming a
  tab to "Family hierarchy and the whole honeycomb of everybody" and watching
  the assertion pass.

The third — `getMinIntrinsicWidth` against the cell, the width of the longest
unbreakable word — fails, and is what produced the table in #111.

### So the labels are shipped cut off, on purpose

The fix is a choice between renaming things the app calls `Journal`,
`Family` and `Settings` everywhere else, hiding the labels on phones, or
going back to four tabs. All three are product decisions, and the second was
written on Day 21 and **deliberately not shipped**: because `Settings` already
overflows a four-tab bar at 390pt, a measure-and-hide rule removes the labels
from effectively every phone at every text size, which is a far larger change
than the defect and the opposite of what ADR-016 was for.

So the defect ships, recorded, with a characterisation test naming exactly
which labels are cut off at which widths — it fails if that set changes, in
either direction. Shipping a known, written-down, tested defect is worse than
shipping a fix and better than shipping an undecided one.

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

**#111 is open and the bar is visibly wrong until it closes.** That is the
real cost of this ADR, and it is larger than "one more icon".
