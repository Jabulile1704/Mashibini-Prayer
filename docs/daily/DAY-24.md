# Day 24 — The accessibility pass that was owed

**Date:** 2026-11-07 · **Phase:** 8, v1.1 front end · **Roles on point:** Developer, QA

## Planned

> A refined icon … **then the whole Day 13 accessibility pass again** … then
> a release.

## Delivered

- `guidelines_test.dart` — tap targets, tappable labels and rendered text
  contrast, swept across every screen
- **Two real defects**, both found by refusing to trust a passing test
- `ThemeData.disabledColor` raised from 2.42:1 to 3.99:1
- 648 tests, up from 610

Not delivered: the icon, because it was already done, and the release,
because tagging is not mine to do.

## The icon was already refined, two ADRs ago

The plan asks for "a refined icon — **the same ring mark**, drawn better".
That sentence was written on Day 16. On Day 17, ADR-017 replaced the ring of
arcs with the comb cluster, and Day 18 regenerated every size from it. The
icon on the phone is the refined one.

Re-drawing it to tick off a plan written eight days ago would be work that
looks like progress. Said here instead.

## Two defects, both found sideways

### A button nobody could press

Day 23's `CombBar` wraps its tap handler in `ExcludeSemantics` and puts
`button: true` on the node outside it. The result: five nodes that announce
themselves as buttons and expose **no activate action**. It shipped to a
phone before anybody noticed.

How it surfaced is the point. `labeledTapTargetGuideline` passed, so —
following Day 21's rule — the labels were stripped on purpose to watch it
fail. **It still passed.** A button with no action is not a tap target that
matcher looks at, so removing the label changed nothing.

The missing label was the probe. The missing action was the defect, and it
was only visible because the probe *failed to fail*.

That is a new shape. Day 21's rule says break the assertion and watch it
fail. This is: **break it, watch it pass, and ask why.** A probe that does
not fail is telling you something about the subject, not only about the
test.

### The disabled treatment, still 2.42:1

Day 19 found a row at 2.42:1 on a simulator and fixed **the row**. Nobody
touched the theme, so `ThemeData.disabledColor` sat at Flutter's default of
38% black for five days — and the next `enabled: false` anywhere in the app
would have reproduced the defect exactly.

Computing it here gives `light a=0.38 surface=2.42`, the same number Day 19
measured by eye. The arithmetic and the simulator agree, which is worth
knowing: the palette test *could* have caught this all along, it was simply
never pointed at `disabledColor`.

55% of `onSurface` now — 3.99:1 light, 5.91:1 dark. WCAG exempts genuinely
inactive controls from a contrast requirement and this is deliberately
stricter, because Day 19's row was not an inactive control. It was
information nobody could read.

**Fixing the instance and not the cause is its own category of mistake**,
and this is the first time this project has caught one.

## What the new sweep does and does not do

Every matcher was broken on purpose before being trusted:

| Matcher | Catches | Does not catch |
|:--|:--|:--|
| `androidTapTargetGuideline` / iOS | a 24pt target | — |
| `labeledTapTargetGuideline` | an unlabelled node | a node with no action |
| `textContrastGuideline` | low-contrast text, flagged at 1.01 | a disabled `ListTile` |

The first draft of that file claimed `textContrastGuideline` "would have
caught Day 19". **It would not**, and the claim was written one day after
#111 was withdrawn for the identical reason. Corrected in place rather than
deleted.

It also only measures **painted** pixels. Settings' turnover row is not
constructed at 390×844, so every screen is scrolled to the bottom and
measured again.

## Contributions

The owner reported that no contributions were showing. They are: **713 this
year, 465 commit contributions**, every day green since 1 November except
today — and today was empty only because the morning's commit had not been
pushed. Pushing it fixed that within the minute.

The mechanism is worth writing down, since it has now caused one false
alarm. GitHub counts a commit when it lands on the **default branch**, which
here is `develop` (ADR-007). Work sitting on a feature branch counts for
nothing until its PR is opened — opening one is itself a contribution — or
merged. So a day spent entirely on an unmerged branch looks like a day off.

**45 contributions are hidden**, in private repositories. *Settings →
Profile → Include private contributions on my profile* surfaces them.

## Tomorrow

The release, which has been ready since yesterday and needs two commands
that this session is not permitted to run.
