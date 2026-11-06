# ADR-022 — The centre of the bar is a comb cell

**Status:** Accepted · **Date:** 2026-11-06 · **Deciders:** Owner
· **Amends:** [ADR-016](ADR-016-four-tabs-and-what-goes-in-them.md),
[ADR-020](ADR-020-a-fifth-tab-and-what-four-was-worth.md)

## Context

The owner, looking at the shipped bar:

> I don't like how awkward the text is on the bottom navigation bar,
> especially for the "weeks ahead" tab … make the "this week" tab at the
> centre and make it stand out a bit and I need the button for it to be like
> a hive-comb and above the rest

Two complaints, and they have different causes.

**"Weeks ahead" wrapped onto two lines.** Five labels share the width of a
phone, and that one is eleven characters with a space in it. Material's
`NavigationBar` wraps rather than truncating, so its icon was pushed up and
the row sat visibly uneven beside four single-line neighbours. Nothing was
clipped — see #111, which claimed otherwise and was wrong — it was simply
ragged.

**This week was the first of five equal icons.** Day 8 decided that the app
answers one question. A bar that gives the answer to that question the same
weight as Settings says the opposite of what every other decision in this
app says.

## Decision

**A custom bar: four labelled destinations, and This week raised between
them as a comb cell.**

```
   Ahead   Journal   ⬡   Family   Settings
                 (raised)
```

### Order

`Ahead · Journal · This week · Family · Settings`. This week moves from
first to third, which is the middle of five. `HomeShell.centre` is a named
constant and a test asserts it stays the middle index, because a lopsided
raised cell would be worse than none.

### One word per label

`Weeks ahead` becomes **`Ahead`**. Beside a centre cell that means *this
week*, "Ahead" is not ambiguous — it is the same distinction in half the
space, and it is the only change to a destination's name.

The centre's label is `This week` and **is not drawn**. The shape is the
label: it is the app's own mark, it is the only thing above the line, and the
screen it opens says "This week" at the top. A word under a hexagon twice the
size of its neighbours would be the third way of saying it. Screen readers
are given the name regardless.

### Why not Material's `NavigationBar`

ADR-016 chose it and it was right at the time. It divides its width evenly
and weights every destination the same, which is a good default and the wrong
answer for an app with one question. There is no supported way to raise one
destination out of it.

The replacement is about sixty lines and reuses `CombMarkPainter.cell`, so
the raised shape is the app's own hexagon rather than a second piece of
trigonometry that can drift from it.

## What this costs

**The platform's accessibility behaviour is now ours to provide.**
`NavigationBar` gave selected state, semantics and touch targets for free.
Written out explicitly instead:

- Every destination is a `Semantics` node with `button: true`,
  `selected:`, and its label — including the centre, whose word is not
  drawn.
- Selection is marked **three ways**: a filled icon, a heavier label, and
  for the centre a filled cell. Not colour alone, which is not a
  distinction everybody can see.
- The centre's tappable box is squared up to `Touch.minimum` rather than
  letting the hexagon's narrow waist be the only thing that answers a
  finger.
- Side labels use `FittedBox(scaleDown)` with `maxLines: 1`, so a large text
  setting shrinks the word rather than wrapping it. That is the specific
  defect this ADR exists to fix, and it is now impossible by construction
  rather than by choosing short words carefully.

**The accessibility sweep is the thing that has to catch regressions here**,
and it already builds the shell at 1.0x, 2.0x and 3.1x.

## Consequences

**ADR-016's "four tabs in a bottom navigation bar" is now wrong twice** —
five, and not a `NavigationBar`. Both amendments are deliberate and both
came from the owner looking at the running app.

**A sixth destination is harder than it was**, which is the right direction.
The bar is now symmetrical around a centre, so adding one means choosing
which side gets three.

**`HomeShell.labels` survives** for the accessibility sweep, derived from
`destinations` rather than written twice.
