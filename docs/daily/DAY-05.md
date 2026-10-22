# Day 5 — The first screen

**Date:** 2026-10-22 · **Phase:** 4, implementation · **Roles on point:** Developer, QA

## Planned

The home screen: this week, who is next, the date it changes hands (R1.1,
R1.2). Issues #3 and #4. Plus, at the stakeholder's request, closing the
persistence gap left open on Day 4 (#36).

## Delivered

| # | What | Where |
|:--|:--|:--|
| #37 | `PreferencesKeyValueStore` tested against the package's own in-memory implementation | merged to `develop` |
| #38 | The This Week screen, `flutter_localizations`, 138 tests | merged to `develop` |

**`lib` is at 100% line coverage.** The app runs, and shows the rota.

## The gap that was closed, and why the original reasoning was half wrong

Day 4 left `PreferencesKeyValueStore` untested on the grounds that thin vendor
wrappers belong to integration rather than to mocking. The half that was right:
do not hand-write a double encoding our *guess* at how a package behaves — the
test then proves the code matches the guess, and passes just as happily when
the guess is wrong.

The half that was wrong: a package that ships its own in-memory implementation
is not a guess. `InMemorySharedPreferencesAsync` is the maintainers'
implementation of their own interface.

That distinction now lives in `TEST-STRATEGY.md`, so the next vendor wrapper
does not get the same free pass. ADR-006's section was corrected rather than
deleted — it records that the reasoning was half wrong, which is more useful
than looking as though it was right all along.

Mutation tested: writing under a different key fails 6 tests, a `delete` that
does nothing fails 2.

## The finding of the day

**The app was rendering American dates to a South African family.**

The first run of the screen tests failed on `25 October 2026`. The screen said
"Sunday, October 25, 2026". Flutter's default `MaterialLocalizations` is
American, and nothing had been said about locales.

The test was right and the app was wrong. Fixed in the app:
`flutter_localizations`, with `en_ZA` **first** in `AppLocales.supported` so a
phone set to a locale we do not list falls back to South African rather than
American order. The widget tests pump the same configuration as the real app,
so they assert what the family actually sees.

A test relaxed to match a wrong implementation would have been worse than no
test at all. This is the second time this week an assertion has been the thing
that was right.

## Decisions

1. **Four screen states, and two of them are nulls that mean opposite things.**
   A null from the repository means "nothing is set up"; a null from the engine
   means "set up, but starts later". Conflating them would tell a family who
   had carefully entered their rota that they had none. There is a test
   asserting they stay distinct.
2. **The clock is a parameter.** The domain refuses to read one (ADR-002); the
   screen is the boundary where one is finally read, and it takes a function so
   the screen is testable on any week of the next decade.
3. **`youAre` is nullable and the screen never guesses.** Telling someone a
   turn is theirs when it is not is worse than showing a name.
4. **Dead code deleted rather than tested.** `DateLabels.medium` was the only
   uncovered code in the repository, because nothing called it — a format
   written for a screen that does not exist yet. The schedule list can add it
   on Day 12, when someone can see what it needs to look like.

## Verified on a device

Built for the iOS simulator and looked at both states, because passing tests do
not tell you whether a screen reads well.

```
This week
Jabulile
until Saturday, 24 October 2026
────────────────────────────────
→  Sisi
   from Sunday, 25 October 2026
```

To see the populated state before setup exists, `main.dart` was temporarily
seeded with a family, screenshotted, and reverted; `git status` confirmed
nothing of it reached the branch. That run was also the first time the
**write** path of `shared_preferences` executed on a device rather than in
memory.

## Open questions

No new ones. **Q1** (turnover weekday) blocks Day 6, which is tomorrow's work.
**Q3** (individual sign-in vs one shared install) blocks Day 7.

Q1 now has a deadline with teeth: the setup screen has to ask for the turnover
day, and a provisional default will have to be chosen and marked as such if no
answer arrives.

## Blocked

Nothing — but see Q1 above.

## Known gaps

- `youAre` is wired to nothing, so the second-person case never fires in the
  running app. Both branches are tested; setup supplies the value on Day 6.
- The populated screen has only been seen with seeded data, by its author.
  Nobody has used it.

## Tomorrow — Day 6, setup

Members, their order, the turnover day and the anchor (R2.1, R2.2). Issues #6
and #7. The first screen that writes rather than reads, and the one that
needs Q1.
