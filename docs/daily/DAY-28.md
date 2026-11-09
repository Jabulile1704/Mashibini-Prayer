# Day 28 — The verses come out, and a requirement goes with them

**Date:** 2026-11-09 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, PO

## Planned

#108, asked for three times across three days: African wisdom instead of
Bible verses.

## Delivered

- 30 Southern African sayings in `assets/sayings.json`, across five languages
- `Saying` and `SayingSource` replacing `Verse` and `Translation`
- A card that leads with the saying's own language and glosses it in English
- **R3.2 rewritten and R3.3 added**; Q2 retired, Q5 opened
- [ADR-025](../adr/ADR-025-the-daily-reading-is-an-african-saying.md),
  superseding ADR-009
- 720 tests, up from 716

## The substitution did not survive the requirement

The ask looked like a content swap: delete 75 verses, add 30 proverbs, ship.
It is not, and the reason is worth writing down.

R3.2 said, since Day 1:

> the **translation** is named, and only a translation whose **licence**
> permits redistribution is bundled.

Both halves evaporate on contact with an oral saying. There is no translator
to name. There is no licence to check, because nobody owns a proverb.

A requirement that cannot be satisfied does not announce itself — it gets
quietly dropped, and the attribution line disappears with it. So the honest
move was to ask what a proverb actually *has*, and the answer is: **a
language**. "isiXhosa" now sits where "WEBPB" sat, and R3.2 requires it in
the same place for the same reason.

The licence half had no equivalent, so it was replaced with a weaker, truer
claim: nothing is lifted from a published collection. Not "we have
permission" — "we have not taken anybody's phrasing".

## The thing this feature could lie about

The person who wrote these sayings down does not speak any of the five
languages they are in.

A review file went to the owner on Day 21 and came back with nothing. That
is an unanswered question, not an approval, and the difference matters: a
misspelled proverb in an isiXhosa family's app, presented with the quiet
confidence of a shipped feature, is worse than no proverb.

So `SayingSource.reviewed` is **a field in the data**, it is false, and the
About screen reads it and says so:

> Nobody who speaks these languages has checked the spelling yet. If
> something reads wrong to you, it probably is wrong — say so and it will be
> fixed.

It is a field rather than a sentence in the screen on purpose. Written into
the screen, the two drift: the app apologises after the wording is approved,
or vouches for it after the wording changes. Read from the data, flipping one
boolean is the whole change — and the test asserts it in **both** directions,
because a caveat that cannot be turned off is as wrong as one that was never
turned on.

This is also why R3.3 exists as a requirement rather than a judgement call.
The failure is silent: unchecked isiXhosa, shown without a word, looks
exactly like checked isiXhosa.

## Thirty, not seventy-five

The verses numbered 75 because a scraper could fetch 75. The sayings number
30 because 30 is how many are worth standing behind, and because **a proverb
is meant to come round** — a family meeting the same thirty over a month is
being taught them.

Every entry added for volume is another chance to misspell somebody's
language. The count is the smaller risk.

isiZulu's absence from the first draft was the only real gap, and a
conspicuous one in a South African family's app: it is the most widely spoken
language in the country. The file now carries isiXhosa, isiZulu, Sesotho,
Setswana and Sepedi.

## What the running app found that the tests did not

The suite was green — 720 tests, analyzer clean — before the app was built
once. Built and launched on the simulator, it hung on the splash screen.

Not this feature. `main()` on this branch still never calls
`Firebase.initializeApp()`, so `FirebaseIdentity()` throws `[core/no-app]`
before the first frame. The fix exists, on `feature/124-the-music-library`,
and has not been merged. Nothing on **this** branch can see that, because no
test in this repository starts the real `main()`.

The branch was not changed to fix it — that is #125's commit and it should
arrive as #125's commit. The startup fix was applied to the working tree
long enough to see the card render, and then reverted.

Two things came out of looking:

- The card is right. *Ubuhle bomzi bubonwa ngabahambi* in italic, the English
  beneath it, `isiXhosa` under that.
- **A green suite on a branch cut before a fix tells you nothing about the
  app it will be merged into.** The retrospective's four species of check
  that cannot fail now have a fifth cousin: a check that passes because it
  never reaches the code that breaks.

## Also

`tool/extract_verses.py` is deleted. It fetched an asset the app no longer
has, and this repository has already learned once what dead weight in a tree
costs (Day 25, the 52 MB APK).

## Open

- **Q5** — who reads the sayings and confirms the spelling in each of the
  five languages? Until somebody does, the app is telling the family it might
  have their languages wrong. That is the right thing to say and a poor thing
  to leave true.
- DAY-27.md is still owed, for the music library and the Azure spike.
