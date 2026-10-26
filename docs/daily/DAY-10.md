# Day 10 — The daily verse

**Date:** 2026-10-27 · **Phase:** 4, implementation · **Roles on point:** Developer, PO

## Planned

One verse a day, the same for everybody, readable with no connection
(#11, #12, R3.1 and R3.2). R3.2 gates R3.1: an unlicensed translation cannot
ship, so the licence question had to be settled first.

## Delivered

| # | What | Where |
|:--|:--|:--|
| #52 | `VerseForTheDay`, 75 bundled WEBPB verses, the extractor, the verse card, ADR-009 | merged to `develop` |

248 tests, 99.5% line coverage. **Q2 is closed.**

## The edition mattered more than the translation

The owner answered Q2 with "the World English Bible". The WEB turns out to be
a family of **six** editions, differing in ways that are not cosmetic:

| Edition | Divine name | Books | Dialect |
|:--|:--|:--|:--|
| `eng-web` Classic | **Yahweh** | 66 + deuterocanon | American |
| `engwebu` Updated | LORD | 66 + deuterocanon | American |
| `engwebp` | LORD | 66 | American |
| **`engwebpb`** | **LORD** | **66** | **British** |
| `eng-webbe` | LORD | 66 + deuterocanon | British |
| `eng-web-c` Catholic | LORD | Catholic canon | American |

What a public API serves for "web" is the **Classic** edition, where Psalm
23:1 reads *"Yahweh is my shepherd"*. Faithful, and not what this family would
expect to read. Taking the obvious default would have been a silent decision
about how a family addresses God.

`engwebpb` was chosen for the two axes that matter here: **"The LORD"**, and
**British spelling**, which is what South African English uses. Both verified
against the shipped file, not assumed.

## What honouring the licence cost

Public domain by explicit dedication. No required attribution, no royalty. One
condition, and it is a trademark condition rather than a copyright one:

> All we ask is that if you CHANGE the actual text of the World English Bible
> in any way, you not call the result the World English Bible any more.

So the text ships **verbatim** — Psalm superscriptions, stray quotation marks
and all. Stripping *"A Psalm by David."* from Psalm 23:1 would read better,
and would mean the translation could no longer be named, which is the thing
R3.2 exists to require.

The selection was curated instead: two psalms swapped for verses whose first
line is not musical direction, and six grammatical fragments swapped for whole
sentences.

**Choose different verses; never edit the ones you choose.**

## What the tests could not see

The suite was green — 248 tests — when the first build went on the simulator
and the screen showed:

> *rejoicing in hope, enduring in troubles, continuing steadfastly in prayer,*

A correct quotation, correctly cited, reading as an accident. Romans 12:12 is a
fragment of a longer sentence, and five others were the same.

No assertion anybody would think to write catches that. Looking at it does.
The honest summary of the day: **tests proved it correct, and eyes proved it
right** — and the second was not redundant.

## A process mistake

Day 10's four commits were made **directly onto local `develop`**, having
forgotten to branch.

Nothing reached the remote. `develop` is protected, the push was refused, and
the commits went to a feature branch instead. Corrected by moving them and
resetting local `develop` to `origin/develop`.

Worth recording because the protection set up on Day 1 is the only reason this
was a nuisance rather than an incident — and because this is the second time
it has caught its author, after the hygiene check on Day 6.

## Decisions

1. **ADR-009 — bundle the WEBPB, choose the verse by arithmetic.** Four phones
   that may never be online together must agree without coordinating, which is
   the same argument as ADR-002.
2. **An epoch-day count, not a hash.** It moves by exactly one each day, so
   the set is walked in order rather than sampled — two consecutive days
   cannot collide onto the same verse.
3. **A failed load renders nothing.** The rota is the app; a missing verse
   should cost the screen nothing. The one place in this app where silence is
   the right answer.
4. **The licence and translation name live in the data**, so the app can
   display them and a future swap cannot silently orphan the attribution.

## Open questions

**Q3** — individual sign-in or one shared install — is the only one left, and
tomorrow is where it stops being deferrable. The journal's entire privacy
claim depends on it.

## Blocked

**Day 11 is blocked on Q3.** Unlike Q1, it cannot be dissolved by asking the
user in the app: it is a fact about how the family will use it. The honest
options are to build the journal device-local only, or to build it synced and
private on the assumption ADR-004 already states — and those are different
products, not different settings.

## Tomorrow — Day 11, the prayer journal

Write an entry, private by construction (#13, #14, R4.1 and R4.3). The rules
proving R4.2 already exist and passed on Day 9; what is missing is the
feature, and the answer to Q3 that decides what "private" is allowed to mean.
