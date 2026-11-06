# Day 21 — Changing the family, and the day

**Date:** 2026-11-05 · **Phase:** 8, v1.1 front end · **Roles on point:** Developer

## Planned

#74's family editor reaches Settings, and the turnover day becomes a real
row. Both were waiting on something: #74 on a Settings screen to live in,
#100 on Day 20's epochs.

Two things arrived mid-day from the owner and were taken on rather than
deferred: a **Family tab**, asked for the same day, and the decision to put
the **songbook before the photographs**. Both are recorded below.

## Delivered

- `FamilyMembersScreen` — add and remove, from Settings (#74)
- The turnover-day row, with a confirmation that names the short week (#100)
- `FamilyTreeScreen` and a fifth tab (#109, ADR-020)
- `lib/src/application/RescheduleReminders`, and the first use of a layer
  `ARCHITECTURE.md` has described since Day 1
- `FamilyEditor.changesTakeEffect`, so a screen can say *when* before it asks
- **#111**, a defect in four shipped releases, found by trying to write an
  assertion that could fail
- 573 tests, up from 518.

## Build it, describe it, save the thing you described

Both screens needed to tell somebody what a change would do before doing it,
and both changes land at a future turnover, so there is a real sentence to
write: *"Sisi has the week before that, and it will be 3 days instead of
seven."*

That sentence could have been composed from the rule. It is read off a real
`Family` that `FamilyEditor` produced instead, and when the family agrees,
**that same object is saved** — not a second one computed after the dialog
closed.

```dart
final Family after = FamilyEditor.changeTurnoverDay(…);   // the change
final Turn? shortened = engine.turnOn(from.subtractDays(1)); // what to say
…
await widget.familyRepository.save(after);                 // the same object
```

The sentence and the outcome are one object, so they cannot drift apart. It
also costs nothing: the preview is the change.

## The list that looked broken by being accurate

The members screen first showed `activeMembers(family, today)` — who is in
the rota **now**. Take somebody out, confirm, and their row is still sitting
there.

That is correct. They really are in the rota until Sunday, because removal
lands at the next turnover (R2.3). It is also indistinguishable from nothing
having happened, which is worse than being slightly wrong.

It shows the roster from the next turnover now, and the paragraph above it
carries the date. Two tests failed on the first version and both were real
rather than mechanical — the row not disappearing, and "a rota needs at least
two people" still showing after a third person was added.

**Accurate and useless is a defect.** That is not a new lesson here — Day 19's
turnover row said a true thing at 2.42:1 contrast — but it is the second time
in three days that the fix was to ask *what is this screen for* rather than
*what is true*.

## A fifth tab, and what it cost

The owner asked for a Family tab, the same day, empty if necessary. ADR-016
says:

> **Four is the ceiling.** A fifth destination means rethinking, not adding.

So it was a reversal, and ADR-020 records it as one rather than letting a test
be quietly edited. The tab holds a flat comb of the people in the rota — not a
tree, and it says so on the screen, because an empty tab reads as broken and a
tab that silently omits three quarters of a feature gets reported as one.

ADR-016 demanded rethinking rather than adding. The rethinking is the rest of
this entry.

## #111 — the third check that could not fail

ADR-016's claim was that five tabs stop working on a phone. Before writing
ADR-020 against it, that needed measuring, and **nothing in the accessibility
sweep had ever built the navigation bar** — it pumps screens, and the bar
belongs to the shell. So the claim could not have been checked when it was
made.

Three assertions were written. The first two cannot fail:

1. **`findsOneWidget` on the label.** A clipped `Text` still carries its whole
   string, so this passes on "Settin".
2. **`RenderParagraph.didExceedMaxLines`.** Always false: `NavigationBar` sets
   no `maxLines` and uses `TextOverflow.clip`. Proved by renaming a tab to
   "Family hierarchy and the whole honeycomb of everybody" and watching the
   assertion pass.

The third works. `getMinIntrinsicWidth` is the width of the longest
unbreakable word, and no amount of wrapping helps a word wider than its box:

```
cell = bar width ÷ destinations
```

| Phone | Four tabs (v1.1.0–v1.4.0) | Five tabs |
|:--|:--|:--|
| 360pt | `Settings` 100 > 90 | `Journal` 88>72, `Family` 75>72, `Settings` 100>72 |
| 390pt | `Settings` 100 > 98 | `Journal` 88>78, `Settings` 100>78 |
| 430pt | — | `Journal` 88>86, `Settings` 100>86 |

**"Settings" has read "Settin" on most phones since Day 18, at the default
text size, through four releases.** Not a large-text defect. The default.

Three "checks that could not fail" now, each a different species:

- **#103** — a step that reported success without reading anything.
- **Day 20** — a comparison that became a tautology when a field became
  derived, and had to be *deleted* rather than repaired.
- **#111** — an assertion aimed at a defect the platform makes invisible: no
  exception, no flag, full string still in the tree.

The first was a broken instrument. The second was a question that had stopped
having two sides. The third is the hardest to spot, because the assertion
looks like it is about the right thing. The only defence found so far is the
one used here: **break it on purpose and watch it pass.** That took one
rename and thirty seconds, and it is the step that would have caught all
three.

## A fix written and deliberately not shipped

Measure the labels, and set `NavigationDestinationLabelBehavior.alwaysHide`
when they do not fit. It was written, it worked, and it was reverted.

Because `Settings` already overflows a **four**-tab bar at 390pt, the rule
removes the labels from effectively every phone at every text size. Visible
labels were the entire point of ADR-016 — three destinations used to be
unlabelled icons in an app bar — so a width calculation that silently undoes
that is a much larger change than the defect it fixes.

The alternatives are renaming things the app calls `Journal`, `Family` and
`Settings` everywhere else, or going back to four tabs. All three are the
owner's decisions, so the defect ships **recorded**: #111, plus a
characterisation test naming exactly which labels are cut off at which
widths, which fails if that set changes in either direction.

Shipping a known, written-down, tested defect is worse than shipping a fix
and much better than shipping an undecided one.

## What else came in

Two product asks, filed rather than built:

- **African proverbs instead of Bible verses** (#108). The picker is already
  content-agnostic and the asset carries its own source block, so this is a
  data change plus a rename — `Verse` is the wrong word for a proverb — and a
  reshaping of R3.2, which currently requires naming a *translation*. ADR-009
  will be superseded. Languages settled: English, Sesotho and isiXhosa,
  Southern African, South African orthography. Content goes to the owner for
  correction before it is written, because a proverb misspelled in a family's
  own language is worse than no proverb.
- **A family tree with photographs and roles** (#109), and a **songbook**
  (#110) split out of it. The songbook is text and costs nothing; it breaks no
  clause of ADR-010 and goes first. ADR-010's third clause — no file uploads —
  stands until something supersedes it on paper, which is the clause doing
  exactly what it was written for.

## Tomorrow

#111's answer, which is a product decision. Then the restyle, now Day 22.
