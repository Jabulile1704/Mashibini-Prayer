# ADR-009 — The verses are bundled, and they are the WEBPB

**Status:** Accepted · **Date:** 2026-10-27 · **Deciders:** PO, Developer

## Context

R3.1 asks for one verse a day, the same for every member, readable with no
connection. R3.2 asks that the translation be named wherever a verse appears,
and that only a translation whose licence permits redistribution is bundled.

R3.2 **gates** R3.1: an unlicensed translation cannot ship at all, so the
licence question had to be answered before the feature was written. It was
open as **Q2** from Day 1.

## Decision

Bundle the **World English Bible, British Edition** (eBible id `engwebpb`,
abbreviation **WEBPB**), as a curated set of 75 verses in
`assets/verses.json`.

The verse for a date is `daysSince(1970-01-01) % verses.length`.

## Why this translation, and why this edition of it

The owner chose the World English Bible. The WEB turns out to be a family of
six editions, and the difference between them is not cosmetic:

| Edition | Divine name | Books | Dialect |
|:--|:--|:--|:--|
| `eng-web` Classic | **Yahweh** | 66 + deuterocanon | American |
| `engwebu` Updated | LORD | 66 + deuterocanon | American |
| `engwebp` | LORD | 66 | American |
| **`engwebpb`** | **LORD** | **66** | **British** |
| `eng-webbe` | LORD | 66 + deuterocanon | British |
| `eng-web-c` Catholic | LORD | Catholic canon | American |

The obvious default — the plain "WEB", which is what public APIs serve — is
the Classic edition, where Psalm 23:1 reads *"Yahweh is my shepherd"*. That is
a faithful rendering and it is not what this family would expect to read.

`engwebpb` was chosen because it differs on exactly the two axes that matter
here: **"The LORD"** rather than "Yahweh", and **British spelling**, which is
what South African English uses. Verified rather than assumed — the shipped
file contains *"The LORD is my shepherd"* and *"neighbour"*, and both are
asserted by a test.

## Licence, checked rather than remembered

From eBible.org's licence page for the edition:

> The World English Bible British Edition is not copyrighted. It is in the
> Public Domain. However "World English Bible" is a Trademark.

The grant explicitly permits to *"copy, publish, proclaim, distribute,
redistribute, sell, give away, quote, memorize, read publicly, broadcast,
transmit, share, back up, post on the Internet, print, reproduce, preach,
teach from, and use"* it. There is **no required attribution**, no royalty and
no notice clause.

There is one condition, and it is a trademark condition rather than a
copyright one:

> All we ask is that if you CHANGE the actual text of the World English Bible
> in any way, you not call the result the World English Bible any more.

## What that condition cost us, and why it was worth paying

The extracted text is used **exactly as published**, including Psalm
superscriptions and the quotation marks that belong to a longer speech.

Two tidier options were rejected:

- Stripping *"A Psalm by David."* from Psalm 23:1 would read better and is a
  change to the text. We would then have to stop calling it the World English
  Bible, which loses the attribution that R3.2 exists to require.
- Trimming the stray quote mark from Numbers 6:24 is the same trade in
  miniature.

So the text is verbatim, and the **selection** was curated instead:

- Psalm 46:1 and 62:1 were swapped for 46:7 and 62:8, whose verse 1 is mostly
  musical direction (*"For the Chief Musician. By the sons of Korah…"*) before
  the line anybody would recognise.
- Six verses that are grammatical fragments of a longer sentence — Romans
  12:12, Ephesians 6:18, Deuteronomy 6:7, Isaiah 40:31, 1 Peter 5:7,
  Colossians 3:23 — were swapped for whole sentences. *"rejoicing in hope,
  enduring in troubles,"* is a true quotation and reads as an accident on a
  card.

**Choose different verses; never edit the ones you choose.** That is the whole
rule, and it keeps the attribution honest.

## Why bundled, and why arithmetic

Bundled because the verses are identical for everyone, never change, and must
read with no connection. One 13 KB asset satisfies all three.

The daily choice is arithmetic on the date for the same reason the rota is
(ADR-002): four phones that may never be online together must agree without
coordinating. An epoch-day count walks the set in order rather than sampling
it, so two consecutive days cannot collide onto the same verse.

## Consequences

**Good**

- No network, no server, no API key, no rate limit, nothing to go down.
- Changing translation later is a data change: regenerate the asset.
- The licence and the translation name travel *in the data*, so the app can
  display them and a swap cannot silently orphan the attribution.

**Bad, and accepted**

- 75 verses repeat every 75 days. Noticeable within a year. Growing the set is
  a regeneration, and `tool/extract_verses.py` is committed so it can be done
  by whoever wants it rather than only by whoever wrote it.
- The curation is one person's taste. Somebody else would pick different
  verses, and nothing about the mechanism prefers mine.
- The source archive is regenerated by eBible periodically, so the shipped
  file records the edition and the date it was retrieved
  (`engwebpb, 2020 stable text`, retrieved 2026-10-27) rather than implying it
  is eternal.
