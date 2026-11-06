# ADR-021 — The tree is not the rota, and photographs stay on the phone

**Status:** Accepted · **Date:** 2026-11-06 · **Deciders:** Owner, Developer

## Context

The owner asked for "a hierarchy of the family … a pic of each person, name,
role … all within this bee-comb like branch tree hierarchy"
([#109](https://github.com/Jabulile1704/Mashibini-Prayer/issues/109)).

Two things in that sentence are decisions rather than work: **who the tree
contains**, and **where the photographs live**.

## Decision 1 — the family is a larger set than the rota

**Everyone in the rota is in the tree. Not everyone in the tree is in the
rota.**

`Family.members` already held more people than `cycle.order` did — somebody
removed from the rota stays in `members` so that a week they led in March
keeps their name (R2.3). The tree makes that gap deliberate and much wider: a
grandchild, a grandparent, a cousin who visits at Christmas all belong in a
family tree, and none of them is owed a week of leading prayer.

So there are two operations where there was one:

| | Writes a cycle? | Takes effect |
|:--|:--|:--|
| `FamilyEditor.addMember` | Yes — a new epoch | The next turnover |
| `FamilyEditor.addRelative` | **No** | Immediately |

`addRelative` writing no cycle is the whole of it. There is no week boundary
for a non-participant to wait for, and nobody's turn moves.

### Why this is the risk worth naming

The app answers one question: whose week is it. A tree that quietly enrolled
people into the rota would break that question in the least visible way
possible — the rota would be *longer*, everybody's turn would be *later*, and
nothing on screen would say why. A family would notice weeks afterwards, and
the cause would be that somebody added a baby to a photo album.

So the screen says it under the button — *"Adding someone here does not give
them a week of prayer"* — and a test asserts that adding a relative leaves
`cycles` untouched.

## Decision 2 — a tree is a set of edges, not a nested type

`Member.parentIds` holds zero, one or two ids, and `FamilyTree` turns edges
into generations:

```text
depth(person) = 0                          if no parent is in the family
              = 1 + max(depth of parents)  otherwise
```

**A family is not reliably a tree.** Remarriages, a grandparent raising a
grandchild, the same person appearing on both sides of a joined family — all
produce shapes a nested `children: [...]` type would refuse to hold. Edges
hold them and the layout decides what to draw.

Three consequences, each of which is a test rather than a hope:

- **Maximum, not minimum.** A child of both a grandparent and a parent is
  drawn below the parent. Taking the minimum would draw them as their own
  parent's sibling.
- **A parent id naming nobody is ignored**, the same way `RotaEngine` drops an
  unresolvable id from a cycle. Denormalised references drift.
- **A loop does not hang the app.** The screen will not offer a name that
  closes one, but two phones merging offline can produce one, and a stack
  overflow is a poor way to find out.

The refusal is also an *absence*: `possibleParentsFor` omits anybody who would
close a loop, so the list cannot contain a wrong answer. A list that holds a
wrong answer and complains after it is picked is worse.

## Decision 3 — photographs are copied, not uploaded

**ADR-010's third clause stands untouched.** It says:

> **No file or image uploads.** Nothing in v1 wants them, and v1.1 should know
> the door is shut.

Nothing here uploads anything. The picker returns a file, the file is copied
into the app's own documents directory, and `Member.photoPath` stores the
path. That is a local file operation, not a transfer, so there is no clause to
supersede and no plan to change.

**A path, not bytes.** Putting image data in the family document would send it
to Firestore the moment #75 lands — which is precisely the upload this avoids.
The field is a string and will have to be dropped on the way in when sync
arrives, because another phone's path means nothing here.

### What that costs, said on the screen

- Photographs **do not sync**. The others cannot see them.
- A **reinstall takes them**, which on a free iOS provisioning profile is
  roughly weekly (#104).

That is the same bargain the journal had before #104, and the mistake then was
that nobody was told until it happened. The Family tab says it in the body of
the screen rather than in a help page nobody opens.

## Alternatives considered

**Firebase Storage.** The honest path to photographs that sync. It needs the
paid plan and therefore a card on file, which is the thing ADR-010 exists to
avoid, and that is the owner's decision rather than a technical one. #109
remains open for it.

**One parent instead of two.** Simpler, and wrong for most families.

**A `relationship` enum** — mother, father, sibling, child. Rejected: a
family's words for its own people are not a list anybody else gets to write.
`Member.role` is free text, and the hint is "Mama, eldest sister, born 2019…"
rather than a dropdown.

**Drawing a line per parent.** Wanted, and not done. It needs the painted
position of every cell, which `Wrap` settles at layout time and does not
report. A single stem between generations says "these came from those" and is
honest; a line drawn between the wrong two people would not be.

## Consequences

**Schema v3**, additive. A v2 document is a family with no tree recorded,
which is what it is. The version still moves because a v2 build would drop the
tree on its next save, and silently losing what somebody has just entered is
worse than refusing to open the document.

**`Family.members` is now the screen's list, not `cycle.order`.** Any screen
showing "the family" has to decide which it means, and get it wrong in the
direction of showing too many rather than enrolling too many.

**The layout is the throwaway part.** When a real branch-drawing layout
arrives, `FamilyTree` and the schema survive and the widget does not. That was
the cheapest thing to build early and the cheapest to replace.
