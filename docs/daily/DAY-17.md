# Day 17 — The design system

**Date:** 2026-11-02 · **Phase:** 8, v1.1 front end · **Roles on point:** Developer

## Planned

Colour, type scale, spacing, components, contrast and dark mode — as tokens
rather than screens, so Day 21's restyle is mechanical.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #86 | `Space`, `Radii`, `TypeScale`, the rebuilt theme, the gallery, 18 contrast assertions | merged |

423 tests, analyzer clean. **No screen was restyled**, which was the point.

## The system found a bug that was eight days old

The version line added on Day 14 sits at **3.00:1** in light mode, against a
4.5 requirement. It had been shipped to two phones.

Day 13's sweep could not have caught it. That sweep checks whether text
*fits*; this is about whether text can be *read*. The cause was
`onSurfaceVariant` faded to 70% — a colour that passes at full strength and
fails once composited onto its background.

Which is the general shape of the thing: **every contrast failure found
today passes at full strength.** A checker that does not composite alpha
would have reported all of them as fine.

## The measurement was wrong twice before it was right

Worth recording honestly, because the lesson is not about contrast.

The first version, written as a throwaway script, reported dark navy on
cream as **3.70:1**. That is implausible — it should be about 13 — and the
only reason it got caught is that the number was implausible enough to
check. It was reading the alpha byte as the red channel.

The second version pinned half-strength black on white at 3.95 from memory
of the usual mid-grey figure. It is 4.00, because `0x80` is 128/255 — a
shade above half, not half.

So the test now **checks itself before it checks anything else**: black on
white is 21:1, white on white is 1:1, and faded black is 4.00:1. A contrast
test that is wrong is worse than no contrast test, because it is believed.

## The grid was never the problem

Thirteen distinct `SizedBox` heights across the app: 2, 4, 8, 10, 12, 14,
16, 20, 24, 28, 32, 36, 44.

The obvious diagnosis — "these are off a 4pt grid" — is wrong. Ten of the
thirteen are divisible by four. The actual problem is that there were
thirteen *choices*, each made in isolation, so two gaps meant to look the
same often did not.

Seven named steps fixes that, and the fix is about reducing decisions rather
than changing arithmetic. Worth noticing, because the wrong diagnosis would
have produced a very similar-looking change that solved nothing.

## Keeping the identity meant not touching the identity

The decision on Day 15 was "keep the identity, rebuild the execution", and
there was one place that was tested.

`ember` measures 3.46:1 on parchment. That clears the 3:1 bar for icons and
the mark — which is all it is used for — and fails the 4.5 bar for text. The
tempting move was to darken the brand colour so one number goes green.

Instead: two accents. `ember` stays exactly as Day 8 chose it, and
`emberDeep` on `emberWash` at 5.58:1 exists for when Day 21 wants a word on
an accent. The gallery renders the safe pair rather than the unsafe one, so
the system stops *offering* the mistake.

Darkening the brand colour would have been solving a problem the app does
not have by changing the one thing the owner asked to keep.

## Most of the type scale is Material's

Said plainly in BRAND.md rather than dressed up. Inventing different numbers
so the scale looks bespoke would be change without improvement.

What was actually missing was the declaration: three roles were customised
in `theme.dart` and the other nine were whatever Material happened to
provide, so nobody could say what `titleMedium` was for or why `bodySmall`
looked the way it did.

## The gallery

`flutter run --dart-define=GALLERY=true` renders every token and component
on one screen.

Behind a dart-define rather than a debug menu or a temporary edit to
`main.dart`, because the version of this that gets used is the one that does
not require remembering to put something back. Reviewed in both light and
dark on a simulator today — dark mode was looked at, not assumed.

## Tomorrow

Day 18 — the navigation shell and the splash. Bottom navigation, the four
tabs from ADR-016, and screens moved into them unchanged. Expect test
maintenance: many of the 423 find widgets through a `Navigator.push` that
will stop existing.
