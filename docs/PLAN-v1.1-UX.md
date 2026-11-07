# v1.1 — The front end

**Status:** Agreed · **Date:** 2026-11-01 · **Days 16–22**

A plan for the look, the navigation and the usability of the app, written
against problems this project actually hit rather than against a checklist.

## What is wrong now, with evidence

These are not opinions about taste. Each one cost something already.

### 1. Navigation is three unlabelled icons in the top-right

Every destination in the app is pushed from `ThisWeekScreen` — four
`Navigator.push` calls, three of them from icon buttons in the app bar.

Top-right is the hardest place on a phone to reach one-handed, and an icon
with no label is a guess. Day 13's accessibility pass found those buttons
had no screen-reader name at all; they were fixed, but the deeper problem is
that **the app has four destinations and no navigation**.

### 2. There is no settings screen, and things have been bolted on instead

- "Which one are you?" is asked during setup, optionally. When reminders
  made it load-bearing on Day 12, the question had to be **duplicated onto
  the Reminders screen** because there was nowhere else to put it.
- Reminders opt-in is a whole screen that holds one switch.
- There is no way to change the turnover day, choose light or dark, or see
  anything about the app except the version line added on Day 14.

Every one of those is a settings row that currently has no home.

### 3. The rota cannot be changed once it exists (#74)

The largest usability failure in the app. `FamilyEditor` adds and removes
members correctly and nothing calls it; setup is reachable only from the
"No rota yet" state. Somebody joins or leaves the family and the app has no
answer.

### 4. The home screen was designed for one question and now holds four

Day 8 deliberately made This Week answer *whose week is it* and left the
space below it empty. It now carries the rota card, the next-turn tile, the
verse, and the version. Each addition was defensible; the sum is not the
screen that was designed.

### 5. Actions give no feedback

Skipping a week silently rewrites the list. There is a screen-reader
announcement (Day 13) and nothing visual — no confirmation, no undo toast,
just a list that is suddenly different.

### 6. Dead ends

"Nothing written yet" and "The rota has not started yet" are statements with
no next step. The journal's empty state in particular is the first thing a
new user sees in that tab.

### 7. The splash is a static image

Flutter's launch screen shows the mark and then cuts to the app. There is no
transition, and on a cold start the rota flashes a spinner first.

## The shape being proposed

**Four tabs**, replacing the app-bar icons:

| Tab | Holds |
|:--|:--|
| **This week** | The rota card, who is next, today's verse |
| **Weeks ahead** | The eight-week schedule, skip and undo |
| **Journal** | Entries and writing |
| **Settings** | Who you are, reminders, the family, turnover day, appearance, about |

Setup stays outside the tabs — it is a first-run flow, not a destination.

## Seven days

### Day 16 — Clear the decks, and audit

Fix **#72** first: release branches cannot be merged, so nothing built after
today can reach a phone until it is decided.

**Decided: stop back-merging with a merge commit.** After tagging, the
release commit is cherry-picked onto `develop` rather than `main` being
merged back. Every branch stays rebaseable, the history stays linear — which
is what ADR-007 wanted and did not get — and the duplicated history the
retrospective found stops growing. It supersedes part of ADR-007, so it is an
ADR rather than a patch.

Worth deciding separately on the day: whether to leave the 72 already-
duplicated commits alone. Rewriting `develop` to remove them would be a force
push over published history, which is a much larger decision than this fix
and probably not worth it.

Then the audit: walk every screen on a real device, at the largest text size
and in dark mode, and write down what is wrong with evidence. Decide the
information architecture above properly and record it as an ADR.

**No visual work.** The point of this day is to know what is being changed
before changing it.

### Day 17 — The design system

**Decided: keep the identity, rebuild the execution.** The cream, navy and
rust stay; the ring mark stays. What changes is the craft — a real type
scale instead of ad-hoc sizes, a spacing scale, a component set, contrast
retuned, and dark mode treated as first-class rather than as an afterthought.

The app should look noticeably better and still look like itself. Day 8's
brand reasoning survives, and so does most of the Day 13 accessibility work,
which a wholesale palette change would have put at risk.

This is where the new look actually happens, and it happens in tokens rather
than in screens, so that Day 21 is mechanical.

Deliverable: an updated `brand/`, a gallery screen that renders every
component for review, and the tokens documented in BRAND.md.

### Day 18 — The navigation shell and the splash

The bottom navigation bar, the four tabs, state preserved across switches.
Existing screens move into tabs **unchanged** — this day is structural.

The splash becomes a transition rather than a cut: the mark holds while the
first read of storage happens, then resolves into This Week. That also
removes the cold-start spinner.

### Day 19 — Settings

The tab that gives all the bolted-on pieces a home: which one are you,
reminders, turnover day, light/dark/system, about and version.

Removes the duplicated "which one are you?" from the Reminders screen, and
folds that screen into a settings row.

> **Done, minus one.** The turnover day is **not a settings row** — changing
> `Family.turnoverWeekday` moves every week boundary the rota has ever had,
> and `RotaEngine` refuses a family whose cycles no longer begin on it, so
> the row would have thrown on the next frame of This Week. It is a new
> cycle epoch, like adding a person. [ADR-019](adr/ADR-019-the-turnover-day-is-an-epoch-not-a-setting.md)
> decides the design; **#100** implements it, with Day 20's family editor,
> which needs the same machinery. The row ships showing the day, not
> changing it.

### Day 20 — The turnover day moves onto the cycle (#100) · **Done**

Split off from the screen when it was costed. #100 is not a row with a
handler behind it: it changes what a week *is*, and the engine, the editor,
the merge and the stored document all have an opinion about that. Doing it
behind the UI, with nothing visible shipping, kept the screen day free to be
a screen day.

Delivered: the turnover day derives from each epoch's own anchor, epochs
resolve newest-first, the week before a change is honestly short, schema v2
with a migration that provably does nothing, and `changeTurnoverDay`. 39 new
tests, nothing on screen. See [DAY-20.md](daily/DAY-20.md) and the
implementation note on
[ADR-019](adr/ADR-019-the-turnover-day-is-an-epoch-not-a-setting.md).

### Day 21 — Change the family (#74), and the turnover day's row (#100) · **Done**

The day that closed the biggest real gap. `FamilyEditor` could add and remove
people from Day 7 and nothing called it; the turnover row was read-only until
Day 20 built the epochs under it.

Both screens say **when** a change takes effect, because neither happens
today, and both do it by building the change and describing the result rather
than describing the rule — so the confirmation and the outcome are the same
object.

**Two things arrived mid-day and were taken on**: a Family tab (#109), which
reversed ADR-016's four-tab ceiling and is recorded in ADR-020, and the
decision to put the songbook (#110) before the photographs.

**It also found [#111](https://github.com/Jabulile1704/Mashibini-Prayer/issues/111)**,
a defect in four shipped releases: tab labels are cut off on most phones at
the default text size, and the accessibility sweep could not see it because
nothing in it had ever built the navigation bar. Open, with a decision owing.

See [DAY-21.md](daily/DAY-21.md).

### Day 22 — Restyle the screens · **Done**

Two items were already done and this plan did not know it: the verse has had
its own card since Day 10, and the version moved to Settings on Day 19. So
the day was the spacing, the undo and the empty states.

Every gap and padding in `lib/src/presentation` is on the scale — it was **28
raw heights against 19 tokenised** on the morning, the scale having been
adopted only by the newest quarter of the app. Snapping them fixed two things
nobody had noticed: each tab used its own horizontal inset, so nothing lined
up between tabs.

**Undo rather than confirmation.** Skipping was already reversible, so the
real gap was narrower and odder: the spoken announcement had gone to screen
readers since Day 13 and a sighted person got nothing. A snack bar now
carries the same string, with Undo in it. A dialog in front of every skip is
a toll paid on each correct tap to catch the rare wrong one.

`spacing_test.dart` fails if a bare number comes back, and has its own test
proving it can fail.

See [DAY-22.md](daily/DAY-22.md).

### Day 23 — The family tree (#109) · **Done**

Unplanned, and asked for by the owner mid-stream. The tab shipped on Day 21
with a flat comb; this is the feature — generations from parent edges,
roles, photographs that never leave the phone, and
[ADR-021](adr/ADR-021-the-tree-is-not-the-rota.md) recording the decision
that matters: **the tree is not the rota**, so adding a relative gives
nobody a week of prayer.

It also began with withdrawing #111, which was wrong, and correcting the six
places the wrong number had reached. See [DAY-23.md](daily/DAY-23.md).

### Day 24 — Accessibility re-pass · **Done, minus the release**

The icon was already refined: this plan asks for "the same ring mark, drawn
better", and ADR-017 replaced the ring with the comb on Day 17 with every
size regenerated on Day 18. Re-drawing it to tick off a plan written eight
days earlier would be work that looks like progress.

The pass itself found two defects — a navigation bar announcing buttons with
no activate action, and `ThemeData.disabledColor` still at the 2.42:1 Day 19
found and fixed only at the call site. See [DAY-24.md](daily/DAY-24.md).

The release is cut, green and waiting on a tag.

### Day 24 as planned — Icon, accessibility re-pass, release

A refined icon — the same ring mark, drawn better — and the launch screen
regenerated from it by `tool/generate_icons.dart`, which already produces
every size from one source.

**Then the whole Day 13 accessibility pass again.** A theme rework is exactly
the change that breaks text scaling and contrast, and the existing sweep will
catch some of it but not contrast or touch-target size. Budget real time for
this rather than treating it as a formality, and it now also owes the
touch-target measurement `Touch.minimum` has promised since Day 17. Day 19
found a row at 2.42:1 by
looking at a simulator, which the sweep had passed.

Then a release. **Not v1.1.0** — that shipped on Day 17, and the app is at
v1.4.0. The #72 caveat this line used to carry is spent too: Day 16 fixed it.

## Risks worth naming now

**The accessibility work is the thing most likely to be quietly undone.**
Day 13 found four real problems at the largest text size. A new type scale
and new spacing can reintroduce all of them. Day 23 exists for this, and the
automated sweep runs on every screen in every state from Day 17 onwards.

**The tests are tied to the current structure.** 405 tests, many of which
find widgets by key or by text. Moving screens into tabs will break some.
That is the tests doing their job, but Day 18 should expect a day of honest
test maintenance, not a surprise.

**Day 8's design intent should not be discarded by accident.** "This screen
answers one question" was a decision, not an oversight. If the new design
moves away from it, that should be a decision too, written down.

## What this plan does not include

Firestore sync (#75), sign-in (#76) and the nominated reminder device (#77).
They are v1.1 backlog items but they are not front-end work, and mixing them
into a UI rework would make both harder to review.
