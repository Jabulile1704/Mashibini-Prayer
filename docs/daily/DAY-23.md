# Day 23 — The family tree, and a retraction

**Date:** 2026-11-06 · **Phase:** 8, v1.1 front end · **Roles on point:** Developer

## Planned

Day 23 was the icon, the accessibility re-pass and a release. It became the
family tree, because the owner asked for it and asked to see it today — and
then, before any of that, it became an apology.

## Delivered

- `FamilyTree`, pure, turning parent edges into generations
- `Member.role`, `Member.photoPath`, `Member.parentIds`; schema **v3**
- `FamilyEditor.addRelative` and `updateMember`
- `Photos`, a seam over the picker that copies and never uploads
- The Family tab rebuilt: generations, photographs, roles, an edit sheet
- **ADR-021**
- **#111 withdrawn**, and every document that repeated it corrected
- 600 tests, up from 583.

## #111 was wrong, and I wrote it into six places first

The owner asked "how is the app now?". Answering it meant running the app,
and the screenshot contradicted a defect report filed the day before.

#111 said the navigation bar's labels had been cut off on most phones since
Day 18, through four releases, with a table of widths. The screenshot showed
all five labels rendering in full.

**Flutter's widget tests render with a fixed-width placeholder font.** Every
glyph is a 1em square:

```
iiiiiiii -> 98.0
MMMMMMMM -> 98.0
```

So `getMinIntrinsicWidth` measured the harness. The tell had been in the
table all along and went unread:

| Label | Characters | "Width" |
|:--|--:|--:|
| `Family` | 6 | 80.4 |
| `Journal` | 7 | 93.8 |
| `Settings` | 8 | 107.2 |

Exactly 13.4 per character. No proportional font behaves like that. A walk
up the render tree also found **no clipper above the label at all**, so even
a genuinely over-wide one would have overdrawn into the gap rather than been
cut off.

### The part that is actually uncomfortable

Day 21's rule was *break the assertion on purpose and watch it pass*. It was
applied, it worked, and it disqualified two of three candidate assertions in
thirty seconds. The survivor could fail. It did fail. **And it was measuring
the wrong thing.**

Nothing in that procedure asks whether the apparatus is sound. "This test can
fail" and "this test measures what I think it measures" are different claims,
and only the first one is cheap to check.

Eight entries in the retrospective are bugs the tests missed and a person
found by using the app. This is the first that the tests **invented** and a
person disproved — the same lesson arriving from the opposite direction, and
the reason the rule is now *the running app is the ground truth*.

The cost of being wrong was not the wrong number. It was that the number went
into an issue, ADR-016, ADR-020, two day logs, a PR body and a test before
anybody ran the app. All now corrected rather than quietly deleted, because
a record that gets silently fixed is a record nobody can date.

## The tree is not the rota

The decision in #109, and the one with the teeth. `cycle.order` says who
takes a week; `Family.members` says who the family is. A grandchild belongs
in the second and not the first.

So `addRelative` writes **no cycle**. There is no week boundary for a
non-participant to wait for and nobody's turn moves.

The failure mode if this were wrong is the quiet kind: the rota would be
longer, everybody's turn later, and nothing on screen would say why. A family
would notice weeks afterwards, and the cause would be that somebody added a
baby to a photo album. The button says it, and a test asserts `cycles` is
untouched.

## A set of edges, because a family is not a tree

`parentIds`, and a function that turns edges into generations. The alternative
— a nested `children: [...]` type — refuses shapes that families actually
have: remarriages, a grandparent raising a grandchild, the same person on
both sides of a joined family.

Three things that are tests rather than hopes:

- **Depth is the maximum over parents**, not the minimum. A child of both a
  grandparent and a parent is drawn below the parent; the minimum would draw
  them as their own parent's sibling.
- **A parent id naming nobody is ignored**, as `RotaEngine` drops an
  unresolvable id from a cycle. Denormalised references drift.
- **A loop does not hang it.** The screen will not offer a name that closes
  one, but two phones merging offline can, and a stack overflow is a poor way
  to find out.

The refusal is an *absence*: `possibleParentsFor` omits anybody who would
close a loop. A list that holds a wrong answer and complains afterwards is
worse than one that cannot.

## Photographs without touching ADR-010

ADR-010 says no file or image uploads. Nothing here uploads anything — the
picker returns a file, it is copied into the app's own directory, and a
**path** is stored. A local copy is not a transfer, so there was no clause to
supersede and no plan to change.

A path and not bytes, deliberately: image data inside the family document
would go to Firestore the moment #75 lands, which is the upload being
avoided.

The cost is real and is in the body of the screen rather than a help page:
they do not sync, and a reinstall takes them. That is the bargain the journal
had before #104, and the mistake then was that nobody was told until it
happened.

## Found by running it, again

The first layout balanced the comb's inset with equal padding on the other
side of every row. It cost 38 points of width, and a four-person family
wrapped after three — **and a wrapped run looks exactly like a generation
below it.** A family of four would have been shown as two generations with
no relationship recorded at all.

No test would have caught it. The tests assert which cells exist and how many
generations `FamilyTree` reports, both of which were right.

## Hygiene, a fifth time

The PR was titled `style(presentation): …`. This project's Conventional
Commit vocabulary has no `style` — feat, fix, docs, test, refactor, perf,
build, ci, chore — and PR hygiene caught it. **Five catches now, five
distinct rules**: the branch name, the body's required heading, the base
branch, the title format, and now the type vocabulary.

Retyped `feat`, which is the more honest label anyway: the undo and the
empty-state buttons are behaviour somebody can see.

## Tomorrow

The release that keeps being deferred. v1.5.0 carries Days 19 to 23, and the
icon and the accessibility re-pass move to Day 24 — including the touch-target
measurement `Touch.minimum` has been promising since Day 17.
