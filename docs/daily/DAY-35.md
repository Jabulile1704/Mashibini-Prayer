# Day 35 — The first draft hid the branch I had just finished testing

**Date:** 2026-11-18 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, Designer

## Planned

#143 — let somebody already in the family admit a second phone. ADR-027
decided the shape two days ago; #148 cleared the way yesterday.

## Delivered

- **#143 closed**, and with it **#75** — open since 1 November
- `JoinAFamily`, six answers rather than an exception, 15 tests
- `FamilyCode` and `AccountCode`, 11 tests
- `PhonesScreen` — both directions of one conversation, 16 tests
- R6.2 marked delivered, **with what is still unproven named**
- 847 tests, up from 805

## Six answers, not an exception

Five of the things that can happen when a phone tries to join are sentences
to say to a person, so they are return values:

| | |
|:--|:--|
| `NotSignedIn` | there is no account to have been admitted |
| `NotAFamilyCode` | no generator could have made that, so **nothing was asked of the network** |
| `NotYourFamilyYet` | there is no family there, **or** this account is not in it |
| `WouldReplaceThisRota` | a question, not a failure |
| `CouldNotAsk` | the network. Nothing changed |
| `Joined` | |

**`NotYourFamilyYet` is deliberately one answer and not two.** Firestore
cannot tell "no such document" from "not permitted", and ADR-027 says it
must not: if they could be told apart, a family id would be worth guessing
at. There is a test named after that sentence, and `RemoteRefused` exists so
that nothing above the data layer has to know what a `FirebaseException` is.

**`NotAFamilyCode` costs nothing.** A family code is `f` and eleven
characters of an alphabet with no vowels and no look-alikes, so a typo is
refusable on the phone. `f1` — what every family was called until yesterday
— is now a typo, which is a pleasing way for #148 to end.

## Joining forgets who this phone belonged to

`youAre` named a member of the rota being put aside. In the new family that
id is either nobody or, worse, **somebody else**. Showing another person's
weeks as yours is the one outcome worse than asking again.

Rejoining the family this phone is already in does not clear it, because the
answer still holds. Both are tests, and the second is the one I would not
have written without the first.

## The finding

The first draft of `PhonesScreen` hid the join field whenever this phone
already had a rota. Sensible-looking: why offer to join when you are already
in a family?

Because `WouldReplaceThisRota` is then **unreachable**. A branch built,
tested, and deliberately broken to watch it fail — in a pull request that
merged an hour earlier — could not happen in the product.

That is the exact shape this project has recorded twice:

| | What was built and tested | How long it was unreachable |
|:--|:--|:--|
| R1.4 | skipping a turn | ten days |
| R2.3 | adding and removing members | ten days |
| Day 35 | replacing a rota by joining | **about forty minutes** |

Forty minutes rather than ten days only because a test would not pass. That
is luck wearing the clothes of process: the test existed because the
application layer was built first and tested on its own, so the UI had
something to disappoint.

The rule it suggests is narrow and cheap: **when a screen decides not to
show something, check what that makes unreachable.** The screen now offers
"Join a different family" with the warning next to it, and the test is named
after the rule — *"the way in is still offered, not hidden"* — so the next
person to tidy the layout has to argue with it.

## A test that passed for the wrong reason

The replace dialog says the two families "cannot be merged". So does the
screen's own helper text, three lines above the button — on purpose, because
somebody should know before they tap, not after.

So `expect(find.textContaining('cannot be merged'), findsOneWidget)` matched
twice and failed. Had the screen's text been worded differently it would
have matched once and **proved nothing about the dialog**, which is #111's
lesson in miniature: an assertion that looks like it is about the right
thing.

It is scoped now:

```dart
find.descendant(
  of: find.byType(AlertDialog),
  matching: find.textContaining('cannot be merged'),
)
```

## The words were most of the work

Four sentences that took longer than the logic:

- *"It is not a password — knowing it is not enough to get in, which is why
  they had to add your code first."* ADR-027's entire argument, in the place
  somebody is about to paste it.
- *"Your journal stays. The rota does not."* The one thing a person needs
  before replacing a rota.
- *"Send it rather than reading it out."* A Firebase uid is twenty-eight
  characters of mixed case with no error detection. `RandomIdGenerator` goes
  to some trouble so our own ids survive being read aloud; a uid has none of
  that and cannot be given it.
- *"Nobody gets in without being named here first."* Under the list of
  members, which is where the decision actually is.

## Both sweeps build it from the first commit

Day 31 recorded that a sweep named "every screen" is one nobody re-reads the
definition of, and that the accessibility sweep had never built the
navigation bar — leaving ADR-016's claim about tabs unverifiable from the day
it was written.

`PhonesScreen` is in the accessibility and guidelines maps in the same commit
that creates it, with a comment saying why.

## What #75 does not have

Evidence.

Every claim about sync in this repository comes from a fake remote or the
rules emulator. **No two real phones have ever exchanged a document.** R6.2's
own words — "two members change the cycle while offline, both reconnect" —
describe something that has not happened. The convergence is asserted, not
observed.

That is written into REQUIREMENTS.md next to the delivery note rather than
left for somebody to notice, because a requirement marked delivered is a
claim and this one is half a claim.

## Open

- **Two real phones.** The only test that counts, and it needs a release.
- **The service account**, for ADR-028's rules deploy. The next release
  fails without it, on purpose.
- **v2.2.0 uncut.** Twenty-three commits unreleased.
- **The owner's iPhone.** Asked for today; it is known to Xcode and offline,
  so nothing could be installed. Signing is configured and ready.
- **Q5** — nobody fluent has checked the sayings' spelling.
