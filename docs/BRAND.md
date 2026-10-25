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
