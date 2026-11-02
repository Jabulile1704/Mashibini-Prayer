# The mark, and how to change it

## What it is

A ring of equal arcs, one of them heavier and warm.

The app answers one question — *whose week is it?* — and the answer is always
"one of us, and then the next one". A divided ring is that idea and nothing
else: a cycle, a current turn, and the certainty that it comes round again.

It is deliberately not praying hands, a dove, or a calendar. Those say
"religion" or "dates". This says *rota*, which is what the app is for.

## It is generated, not drawn

`lib/src/presentation/brand/mark.dart` is the only source. One command rewrites
every icon, every density and the launch images:

```bash
flutter test tool/generate_icons.dart
```

That is a test only because it is the one way to get a real Flutter canvas
without a device attached. It asserts nothing — it paints, and it writes.

The same reasoning as Zaka's `GenerateAppIcon.swift` and Yetsa's
`MakeIcon.swift`: a binary somebody exported once from an editor is a dead end
the first time it needs changing.

### What one run writes

| Where | What |
|:--|:--|
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | 15 sizes, 20px to 1024px |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/` | the mark at 1x, 2x, 3x |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | 5 densities |
| `android/app/src/main/res/mipmap-*/launch_image.png` | 5 densities |

Icons are opaque: an App Store icon may not carry an alpha channel, and a
transparent Android icon becomes whatever is behind it. Launch images are
transparent, because the platform paints the background — the storyboard and
`launch_background.xml` both carry `Palette.ink`, so there is no seam.

## The one piece of geometry worth knowing

A round cap extends half the stroke width past each end of an arc. The current
turn's arc is 45% heavier than the others, so without correction its caps eat
further into the gaps and the ring comes out uneven — the difference between a
mark that looks drawn and one that looks approximate.

So each arc's sweep subtracts its own cap overhang, and each is centred in its
share of the circle rather than started at its edge. Thickening one arc then
changes its weight without moving it off its quarter.

## Inside the app it is an instrument, not a decoration

The home screen draws the same mark live: as many arcs as there are people,
with this week's filled. The icon is a *generic* cycle; the card shows *your*
cycle and where the family has got to.

A two-person family gets two arcs, which reads as two halves facing each other
rather than as a ring. That is honest rather than ideal, and it was left alone:
making the mark lie about how many people are in the rota to look more like a
ring would be the wrong trade.

## Colours

**Superseded on Day 18 — see ADR-017.** The indigo and rust below were
replaced by the family's totem, the bee. Kept here because the reasoning
about *why* a palette is chosen rather than seeded still holds, and because
an ADR that supersedes something should leave the something readable.

### The bee palette

`lib/src/presentation/brand/palette.dart`.

| | | |
|:--|:--|:--|
| `honey` | `#E8A317` | The accent at full strength — on dark grounds only |
| `amber` | `#A86B0A` | Honey deepened until it can be seen on wax |
| `amberDeep` | `#8A5606` | Deeper still, for accent **words** on wax |
| `ink` | `#1A1410` | The dark of a bee, and the inside of a hive. Brown, not black |
| `wax` | `#FFF9ED` | The pale ground |

**The rule that shaped it, measured rather than guessed:** honey on wax is
**2.07:1**, below even the 3:1 bar for a graphic. On ink it is **8.41:1**.

That is how a bee reads — the yellow is only ever seen against black. So
honey keeps full strength on dark and deepens to amber on wax. The totem's
colours are never dropped; they change register. Which is also how the app
offers light, dark and system without losing them.

### The mark

A cluster of comb cells, one filled. **One cell per person; the filled one is
whose week it is**, so the logo carries the app's state rather than sitting
beside it.

Cells orbit a ring rather than packing into a true lattice: a real honeycomb
is beautiful at poster size and mud at twenty pixels, and surviving small is
the only thing this mark must do.

---

## Colours (superseded, Day 8)


`lib/src/presentation/brand/palette.dart`.

| | | |
|:--|:--|:--|
| `ink` | `#1F2A44` | Deep indigo. Dark enough to read white on, soft enough not to be navy. |
| `ember` | `#C2703D` | The accent, used for exactly one thing: the current turn. |
| `parchment` | `#FAF7F2` | The light ground. Warm, so the app does not feel clinical. |

Warm against cool, so the eye lands on the current turn without any other part
of the screen needing to be brighter. One accent, one job.

**`launch_ink` in `android/app/src/main/res/values/colors.xml` duplicates
`Palette.ink` and is kept in step by hand.** There is one launch colour and it
changes about never, which is a better trade than generating a resource file.

## The design system

Added on Day 17. The mark and the palette were decided on Day 8; what was
missing was everything around them. Fourteen screens' worth of spacing had
been decided one gap at a time.

### Spacing — `Space`, in `brand/tokens.dart`

| | | |
|:--|--:|:--|
| `xs` | 4 | Between a label and the thing it labels |
| `sm` | 8 | Between tightly related lines |
| `md` | 12 | Inside a row or list item |
| `lg` | 16 | The default gap, and the screen gutter |
| `xl` | 24 | Between groups in the same section |
| `xxl` | 32 | Between sections |
| `xxxl` | 48 | Around something meant to stand alone |

There were **thirteen** distinct `SizedBox` heights before this: 2, 4, 8, 10,
12, 14, 16, 20, 24, 28, 32, 36 and 44. Most sat on a 4pt grid, so the grid
was never the problem — the problem was that every gap was a fresh decision
and two gaps meant to match often did not.

### Radii — `Radii`

`sm` 12 for inputs, `md` 16 for buttons and tiles, `lg` 28 for cards. Was 14,
16, 18 and 28, with no rule about which to use.

### Type — `TypeScale`, in `brand/type_scale.dart`

`display` 36 · `headline` 24 · `title` 16 · `bodyLarge` 16 · `body` 14 ·
`caption` 12 · `label` 13 (tracked wide).

Most of these are Material's own sizes, deliberately. Inventing different
numbers so the scale looks bespoke would be change without improvement. What
was missing was the **declaration**: three roles were customised and the
other nine were whatever Material happened to provide, so nobody could say
what `titleMedium` was for.

Colour is applied in `TypeScale.themed()` rather than baked into each style,
because a style carrying a colour from the wrong theme is the commonest way a
dark mode ends up with one unreadable line in it.

### Contrast is measured, not asserted

`test/presentation/contrast_test.dart` checks every text pair in both themes
against WCAG 2.1 — 4.5:1 for body, 3:1 for large text and graphics — and
**composites alpha before measuring**, because every failure found on Day 17
was a colour that passes at full strength and fails once faded.

It found that the version line added on Day 14 sat at **3.00:1** in light
mode for eight days. Day 13's sweep checks that text fits; it cannot check
that text can be read.

The test checks itself first. A contrast test that is wrong is worse than
none, because it is believed — and the first version of this measurement,
written as a throwaway script, read the alpha byte as red and reported
black-on-white as 3.7:1.

### Two accents, not one

| | | |
|:--|:--|:--|
| `ember` | `#C2703D` | Graphics only — icons, the mark. 3.46:1 on parchment, which clears the 3:1 bar for non-text |
| `emberDeep` | `#8F4A20` | When the accent must carry a word. 5.58:1 on `emberWash` |
| `emberWash` | `#F4EAE0` | A pale accent ground for a chip or badge |

Splitting them was cheaper than darkening the brand colour to solve a problem
the app does not yet have. `secondary` stays exactly as Day 8 chose it; the
system simply stops offering an unsafe pair for text.

### Looking at it

```bash
flutter run --dart-define=GALLERY=true
```

Renders every token and component on one screen. It costs nothing in a normal
build and means reviewing the system never requires editing `main.dart` and
remembering to put it back.
