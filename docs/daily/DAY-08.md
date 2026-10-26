# Day 8 — Design

**Date:** 2026-10-25 · **Phase:** 3, design (visual) · **Roles on point:** Developer, PO

> Written late, on Day 9. See "The log that was missing" at the bottom.

## Planned

Nothing. **This day was not in the plan at all.**

Asked how the app looked, the honest answer was: Flutter's default logo,
untouched since the scaffold, and a stock Material card on a mostly empty
screen. The 14-day plan had Day 2 for architecture and Day 13 for
accessibility, and nothing anywhere for an icon, a splash or a considered
look.

The plan went from 14 days to 15 and the design day was **inserted at 8**
rather than appended, because the verse and journal land on Days 10 and 11:
deciding what the home screen *is* costs far less before it is filled than
after.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #48 | The mark, the icon generator, every icon and launch image, the palette and theme, the redesigned home screen, `docs/BRAND.md` | merged to `develop` |

Also, at the owner's request, the app was built and installed on their iPhone
— twice, since the first install predated the icon work.

## The mark

A ring of equal arcs, one of them heavier and warm. The app answers one
question — whose week is it — and the answer is always "one of us, and then
the next one". A divided ring is that idea and nothing else.

Deliberately not praying hands, a dove or a calendar: those say "religion" or
"dates", and this says *rota*, which is what the app is for.

**Generated, not drawn.** `flutter test tool/generate_icons.dart` rewrites 15
iOS sizes, 5 Android densities and every launch image from one painter — the
same practice as Zaka's `GenerateAppIcon.swift` and Yetsa's `MakeIcon.swift`.
A binary exported once from an editor is a dead end the first time it needs
changing.

## The detail that took two renders

The first icon came out with uneven gaps. A round cap extends half the stroke
width past each end of an arc, and the current turn's arc is 45% heavier than
the others, so its caps ate further into the gaps either side of it.

Each arc's sweep now subtracts its own cap overhang, and each is centred in
its share of the circle rather than started at its edge. That is the
difference between a mark that looks drawn and one that looks approximate,
and it is the only non-obvious line in the painter — so it is commented, and
written up in `docs/BRAND.md`, because it is exactly the line somebody would
later delete as redundant.

## Decisions

1. **The mark is an instrument inside the app, not a decoration.** The home
   screen draws it live: as many arcs as there are people, with this week's
   filled. The icon is a generic cycle; the card is *your* cycle. That answers
   "who is next after next" without anybody reading a list.
2. **Colours chosen, not seeded.** `ColorScheme.fromSeed` is a good default
   and it is a default — every app that uses it looks like every other app
   that uses it. Parchment and ink, with one warm accent used for exactly one
   thing: the current turn.
3. **A two-person family draws two arcs**, which reads as halves rather than
   as a ring. Honest rather than ideal, and left alone: making the mark lie
   about how many people are in the rota, to look more like a ring, would be
   the wrong trade.
4. **`launch_ink` duplicates `Palette.ink` by hand.** There is one launch
   colour and it changes about never, which beats generating a resource file
   to avoid a duplication nobody will trip over.

## Verification worth noting

**All 220 tests passed unchanged**, including the Day 5 test asserting the
leader's name is the largest text on screen. That test was written precisely
so a later redesign could not quietly bury the one thing that matters, and a
redesign is exactly what it just survived.

Looked at on the simulator in light and dark, and at the 1024px and 40px
renders to check the mark still reads when small.

## The log that was missing

**This file was written on Day 9, after the gap was noticed in a file count.**

Day 8's work merged without a log, which breaks the working agreement in
`SDLC.md` that each day is summarised at its close. It is worth more than
tidiness: the scheduled daily task works out which day it is by reading the
highest `DAY-NN.md` in this directory, so a missing file would have had an
unattended run skip straight from 7 to 9 and never notice.

Why it happened: Day 8 was unplanned, started mid-conversation, and
interrupted by a request to install the app on a phone. The day's *work* had a
PR and a review; the day itself had no closing ritual because it never had an
opening one.

The fix is this file, and the lesson is that an unscheduled day still needs
the same close as a scheduled one — the process is not only for the days that
were planned.

## Open questions

No new ones. **Q2** and **Q3** both still open, and the Firebase project still
needs the owner's account.

## Next — Day 9, security rules

Firestore rules and their tests (#10). Provisional on Q3, as stated in advance
in the Day 7 log.
