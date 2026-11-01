# ADR-016 — Four tabs, and what goes in each

**Status:** Accepted · **Date:** 2026-11-01 · **Deciders:** Owner, Developer

## Context

The app has four destinations and no navigation. Every one of them is pushed
from `ThisWeekScreen`:

```
$ grep -c "Navigator.of(context).push" lib/src/presentation/screens/*.dart
journal_screen.dart:1
this_week_screen.dart:4
```

Three of those four are icon buttons in the top-right of the app bar — the
hardest place on a phone to reach one-handed, and the easiest place to miss.
Day 13's accessibility pass found all three had no screen-reader name at
all; they were given labels, but a label does not make an unlabelled icon
discoverable to somebody looking at the screen.

Day 8 designed This Week to answer one question. It now carries the rota
card, the next-turn tile, the verse and the version line. Each addition was
defensible on its own and the sum is not what was designed, because there
was nowhere else for any of them to go.

## Decision

**Four tabs in a bottom navigation bar.**

| Tab | Holds | Why there |
|:--|:--|:--|
| **This week** | The rota card, who is next, today's verse | The question the app exists to answer, and the thing somebody opens it for |
| **Weeks ahead** | The eight-week schedule, skip and undo | Planning, which is a different act from checking |
| **Journal** | Entries, and writing one | A place you go to deliberately, not something you glance at |
| **Settings** | Who you are, reminders, the family, turnover day, appearance, about | Everything currently bolted onto a screen that is not about it |

### Setup is not a tab

It is a first-run flow. Making it a destination would put a "set up the
rota" tab next to three tabs that only work once the rota exists.

After first run it is reachable only from Settings, as the individual
operations it performs — change the family, change the turnover day — rather
than as a wizard somebody re-runs.

### The version line moves to Settings

It was put at the foot of This Week on Day 14 because there was no Settings
screen. Settings is where somebody looks for it, and This Week gets a little
of its focus back.

### What Settings absorbs

- **"Which one are you?"** — currently asked in setup *and* duplicated onto
  the Reminders screen, because Day 12 made it load-bearing and there was
  nowhere else to ask it. One home, one asking.
- **Reminders** — currently a whole screen holding one switch and a list.
  Becomes a row that opens a detail view.
- **The family** (#74) — add and remove members, which `FamilyEditor` has
  supported since Day 7 with nothing calling it.
- **Turnover day** — chosen once in setup and never changeable.
- **Appearance** — light, dark, or follow the system.

## Consequences

**Day 8's intent is kept deliberately, not by accident.** "This screen
answers one question" was a decision. Four tabs make it possible to honour
again, because the other three things now have somewhere to live. The verse
stays, because the verse is part of the daily moment rather than a separate
errand.

**Tests will break.** 405 of them, many finding widgets by key or by text
through a `Navigator.push` that will no longer exist. That is the tests
doing their job; Day 18 should budget for it rather than be surprised.

**Four is the ceiling.** A fifth destination means rethinking, not adding —
five tabs on a phone is where a bottom bar starts to be a worse answer than
a menu.

## Alternatives considered

**A drawer.** Hides every destination behind a gesture most people never
make, and is worse for one-handed reach than the app bar it would replace.

**Three tabs, with the journal inside This Week.** Tempting, because the
journal is part of the daily moment. Rejected: writing is a deliberate act
and the journal already has a list, an editor and an empty state. It is a
place, not a card.

**Keep the app bar icons and only add Settings.** The cheapest change and it
fixes the smallest part of the problem. Discoverability is the actual
complaint; one more icon in the top-right does not address it.
