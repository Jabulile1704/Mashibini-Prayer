# ADR-017 — The identity is the family's totem

**Status:** Accepted · **Date:** 2026-11-02 · **Deciders:** Owner, Developer
**Supersedes:** the palette and mark decided on Day 8 (BRAND.md), and the
two-accent scheme of [ADR-014](ADR-014-the-android-key-is-for-continuity.md)'s
sibling note in BRAND.md

## Context

Day 8 chose indigo, rust and parchment, and a mark made of arcs. The
reasoning was sound and entirely abstract: a ring is a cycle, one arc is a
turn.

On Day 17 the owner was asked how far a visual change should go and answered
"keep the identity, rebuild the execution". On Day 18 he said something more
useful: **the Mashibini totem is the bee.** That is not a preference about
colour, it is a fact about the family, and it outranks a palette chosen for
being quiet.

## Decision

**Honey, ink and wax, and a mark made of comb cells.**

Three of the four directions explored were viable. The owner chose **dark
hive**: dark-first, honey glowing against it, the comb as a quiet texture
rather than a pattern.

## What the measurement decided

Bright honey `#E8A317` on wax `#FFF9ED` measures **2.07:1** — below even the
3:1 bar for a graphic, let alone 4.5:1 for a word. On ink `#1A1410` it is
**8.41:1**.

That is not an obstacle. **It is how a bee reads: the yellow is only ever
seen against black.** So the palette follows the animal:

| | On ink | On wax |
|:--|:--|:--|
| Accent | `honey #E8A317` at 8.41:1 | `amber #A86B0A` at 4.20:1 |
| Accent text | honey, 8.41:1 | `amberDeep #8A5606` at 5.86:1 |

The totem's colours are never dropped. They change register, which is also
the answer to "light, dark and system without losing the bee colours": the
bee is present in all three, strongest where it belongs.

This is the same two-accent shape ADR-014's companion reasoning arrived at
for rust, reached again from a different direction — which is some evidence
it is the right shape rather than a workaround.

## The mark does work now

A comb cell is the one bee shape that is not a cartoon. A face, wings or
antennae do not survive 56 pixels; a hexagon does.

More than that: **one cell per person, the filled one is whose week it is.**
The logo is the app's state rather than a picture beside it — a family of
four reads as four cells, a family of six as six, and an empty comb is a
family that has not set up a rota.

Cells orbit a ring rather than packing into a true lattice. A real honeycomb
is lovely at poster size and turns to mud at twenty pixels, and surviving
small is the only thing this mark must do.

## Consequences

**Day 8's reasoning is superseded, not discarded.** "Equal parts, one of
them current, a cycle that comes round" is exactly what the comb says. Only
the geometry changed.

**The contrast test earned its keep on its first real test.** The new dark
divider was written at `#332819` and the test failed it at **1.27:1** — a
divider nobody can see is a divider that is not there. It is `#423524` at
1.53:1 because a test written on Day 17 refused the first thing typed on Day
18.

**The app icon and both launch screens regenerate from the mark**, as they
have since Day 8 — one command, 28 files. The launch colours in
`colors.xml` and `LaunchScreen.storyboard` are still kept in step by hand,
and were.

**This is a visual change, not a structural one.** All 423 tests passed
without modification, which is the evidence that the design system built on
Day 17 did its job: the identity lives in tokens, so replacing it touched
two files and no screen.

## Alternatives considered

**Honeycomb-structural (direction A).** Hexagons as the layout system, not
just the mark. Distinctive, and the comb pattern behind every surface risks
becoming the thing people see instead of the name.

**Warm minimal (direction B).** The cleanest of the three, and the bee was a
whisper — a totem nobody notices is not a totem.

**Darkening honey until it works on wax.** One colour, one number green, and
a bee the colour of mustard. Rejected: the register change is truer to the
animal and keeps the yellow vivid where it can be.
