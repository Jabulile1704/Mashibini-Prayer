# ADR-025 — The daily reading is an African saying, not a Bible verse

**Status:** Accepted · **Date:** 2026-11-09 · **Deciders:** PO, Developer
· **Supersedes:** [ADR-009](ADR-009-the-verses-are-bundled-webpb.md)

## Context

ADR-009 settled Q2 and shipped 75 World English Bible verses as
`assets/verses.json`, with the translation named under every one because R3.2
required it.

The owner then asked three times, over three days, for African wisdom instead
of scripture (#108). That is not a bug report and there is nothing to debate:
it is the product owner saying what the app is for. The interesting part is
that **the substitution does not survive the old requirement**, and pretending
it does would have shipped a quiet falsehood.

R3.2 as written asks for two things:

1. name the **translation** wherever a reading appears, and
2. bundle only a translation whose **licence** permits redistribution.

A traditional saying has neither. There is no translator to name and no
licence to check, because nobody owns it. That is a *different* problem rather
than no problem — and a requirement that cannot be satisfied is worse than one
that is hard, because it gets quietly dropped and nobody notices the
attribution has gone.

## Decision

**Replace the verses with 30 Southern African sayings**, in
`assets/sayings.json`, and rewrite R3.1 and R3.2 around what a proverb
actually has.

- `Verse{reference, text}` and `Translation{name, abbreviation, licence,
  notice}` become `Saying{text, original?, language}` and
  `SayingSource{tradition, languages, notice, reviewed}`.
- **The language is the attribution.** "isiXhosa" sits where "WEBPB" sat. A
  proverb without its language is a sentence nobody can place; with it, it is
  attributed as honestly as an oral form can be.
- **The saying leads in its own language**, with the English beneath it as a
  gloss. The family's tongue is the text and the English is the aid, not the
  other way round.
- `Saying.original` is **nullable on purpose**. A saying whose wording nobody
  here can vouch for ships in English with its language named, rather than
  guessed at in a family's own tongue. A proverb misspelled in isiXhosa, in an
  isiXhosa family's app, is worse than no proverb.
- The selection arithmetic is unchanged: `daysSince(1970-01-01) % count`. It
  was never about scripture. It is the same reasoning as the rota (ADR-002) —
  nothing to coordinate, nothing to advance, and the right answer on a phone
  that has been off for a month.

### Nothing is quoted from a collection

The sayings belong to nobody; a particular published *English wording* of them
belongs to whoever published it. So none is lifted from a collection. Each is
written from widely circulated wording, and the file says so in `notice`.
This is the honest replacement for the licence check: not "we have permission"
but "we have not taken anybody's phrasing".

### The file says whether a speaker has checked it

`SayingSource.reviewed` is a field in the data, and it is **false**.

The person who wrote these sayings down does not speak isiXhosa, isiZulu,
Sesotho, Setswana or Sepedi. A review file went to the owner and did not come
back with corrections, which is not approval — it is an unanswered question.
Shipping the wording anyway is defensible; shipping it *as though a speaker had
approved it* is not, so the About screen reads the flag and says plainly that
nobody has checked the spelling, and asks the family to say if something reads
wrong.

It is a field rather than a sentence in the screen for a reason: a sentence
would let the two drift. Written in the screen, the app would carry on
apologising after the wording was approved, or carry on vouching for it after
the wording changed. Read from the data, flipping one boolean is the whole
change, and a test holds that line in both directions.

## Why five languages and only thirty sayings

The family is South African, so isiZulu's absence from the first draft was
conspicuous: it is the most widely spoken language in the country. The file
now carries isiXhosa, isiZulu, Sesotho, Setswana and Sepedi.

Thirty, against the verses' seventy-five, is deliberate. A proverb is *meant*
to come round — a family that meets the same thirty over a month is being
taught them, which is what a proverb is for. Thirty widely attested sayings
also beats seventy-five where the last forty-five were scraped for volume, and
every entry added without a speaker's eye is another chance to misspell
somebody's language.

The same wisdom appears in more than one of them on purpose: `Umntu ngumntu
ngabantu` and `Motho ke motho ka batho` share an English gloss and are not
duplicates. The card leads with the original, so they do not read as a repeat
— and the uniqueness test is keyed on the saying *and* its language, which is
the only way that can be stated without lying in either direction.

## Consequences

- **R3.1 and R3.2 are rewritten** in `docs/REQUIREMENTS.md`. Q2 stays closed:
  it asked which translation may be bundled, and the answer is now that none
  is.
- The old asset, entity, loader, card, tests and the `tool/extract_verses.py`
  fetcher are **gone rather than kept beside the new ones**. A fetcher for an
  asset the app no longer has is dead code, and this repository has already
  learned once what happens when dead weight is left in a tree.
- **ADR-009's reasoning is still worth reading** and is not edited. The
  edition comparison in it — six WEB editions differing in the divine name,
  the canon and the dialect — is exactly the kind of care this decision also
  needs, and did not get, from somebody who speaks the languages.
- **The contrast floor moved.** The gloss is set at 70% of `onSurface` where
  the card carries an original, fainter than the 82% the verse used. That is a
  new number against a bar that has caught a real defect before (the version
  line, Day 14), so the sweep now measures both.
- **The open question is a review, not a feature.** Until a speaker reads the
  file, the app is telling the family it might have their languages wrong.
  That is the right thing to say and a poor thing to leave true.
