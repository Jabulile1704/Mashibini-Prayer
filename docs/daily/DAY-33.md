# Day 33 — "So is it fine now?"

**Date:** 2026-11-18 · **Phase:** 9, the v1.1 backlog · **Roles on point:** DevOps, Developer

## Planned

Nothing. The owner deployed the security rules and asked a four-word
question.

## Delivered

- **#146** — the rules deploy from the release, tested at the tag
- `publish` cannot ship an APK whose rules never went out
- **ADR-028**, **N11**, and a seventh species in the retrospective
- `docs/FIREBASE-SETUP.md` brought up to date, three weeks stale
- The five steps for the one credential a workflow cannot create itself

## The honest answer was "I cannot tell you"

The deploy worked. The CLI said so:

```text
✔  cloud.firestore: rules file firestore.rules compiled successfully
✔  firestore: released rules firestore.rules to cloud.firestore
```

So I checked, from outside, what the live database now does:

```text
families           403
memberships        403
journals           403
not-a-collection   403
```

Correct. And **identical to the four answers it gave before the deploy**,
which I had taken the day before while deciding whether a release was safe.

A correct ruleset refuses an unauthenticated stranger. So does a database
created in production mode with no rules at all. **From outside there is no
probe that distinguishes them** — which is the rules working precisely as
designed, and also the reason "it is deployed" was an unverifiable claim.

The only observer who can tell the difference is an authenticated member of
the family, holding a real phone. That is not something this laptop can be.

## Which turned out to be a finding, not a limitation

`firestore.rules` has been tested against the emulator since Day 9 —
thirty-four tests now, in a required check, on every pull request. The live
database served whatever was last pushed by hand, which until 18 November
was nothing.

Both halves were working. The file was correct and proved correct. The
database was refusing everybody, exactly as it should by default. Neither
was wrong, and **they were not the same artefact.**

| What was checked | What was answering requests |
|:--|:--|
| `firestore.rules` in the repository, in an emulator | a ruleset in Google's project, last written from a terminal |

The retrospective now holds seven entries, and this one is a new shape. The
others are a check that could not fail, a check pointed at the wrong
question, no check at all, and correct analysis with nothing able to act on
it. This is a check that **could** fail, did its job honestly, and was aimed
at a copy.

The generalisation is the part worth keeping: **ask what the tested thing is
a copy of.** A config file, an infrastructure template, a schema, a ruleset
— anything authored in one place and executed in another has this shape, and
the test will pass on the version nobody is running.

## The fix is to stop having two copies

Not another test. A comparison between the file and the live ruleset would
work, and it needs a credential anyway — and having paid that price, the
better thing to buy with it is a deploy rather than an audit. A comparison
is one more thing that can agree with itself.

So the release deploys them:

- a `rules` job runs the emulator suite **on the tagged commit** — not
  trusted from the pull request that merged it, because what is deployed has
  to be what was tested at that exact revision;
- then it deploys to `mashibini-prayer`;
- `publish` lists it in `needs`, so no APK reaches a release page whose
  rules never went out.

What is live is then what was tested, by construction. Nothing left to
compare.

## It fails rather than skips

The obvious shape for a step whose secret might be missing is:

```yaml
if: ${{ secrets.FIREBASE_SERVICE_ACCOUNT != '' }}
```

That produces a green release whose rules were never deployed — #146 with
one more layer on top. Six of the seven entries in the retrospective are
some version of this mistake, so the step's only job is to notice the
absence and say so:

```text
::error::FIREBASE_SERVICE_ACCOUNT is not set, so the rules cannot be
deployed and this release is refused.
```

**This means the next release fails until the owner creates the service
account.** That is the intended behaviour and not an oversight. The five
steps are in `docs/FIREBASE-SETUP.md`; the role is Firebase Rules Admin and
nothing else, so the credential cannot read the family's data.

## The hazard that ordering cannot fix

Rules take effect the instant they are deployed. An APK reaches a phone
whenever somebody gets round to installing it. Days apart, and not
controllable.

| A rules change that… | Deploying first is… |
|:--|:--|
| **grants** access the new app needs | right — the app would be refused otherwise |
| **withdraws** access the old app uses | **wrong** — every installed copy breaks at once |

The workflow deploys before publishing, which is right for the first row and
dangerous for the second. No ordering solves it: a withdrawal has to ship as
two releases, one that stops the app needing the access and a later one that
removes it.

Written down because the failure is silent and remote. Nobody's build goes
red. The family's phones stop syncing, and the person who deployed is not
holding one of them.

## A document three weeks out of date

`docs/FIREBASE-SETUP.md` still opened with:

> **Status: part done.** The project exists and is configured; the apps are
> not registered yet and nothing in this repository talks to Firebase.

Both clauses had been false since Day 11 and Day 32 respectively. It also
still carried Q3 as the decision that "has to come first" — answered on Day
11 — and ADR-001's wrong assumption that Firestore has no South African
region, three paragraphs after the table that correctly says
`africa-south1`.

That is the third day running on which a document flattered the project by
being stale. Day 31 found two in `REQUIREMENTS.md`. There is no automation
for this and it is not obvious there should be; what there is now is a
habit of opening the file that describes the thing you just changed.

## Open

- **The service account.** The next release fails without it, on purpose.
- **#143** — a second phone joining. Still a decision: what the app says
  when the joining phone already has a rota that cannot be merged.
- **Nothing has yet run against the real Firestore.** The rules are live and
  the app is wired, and every piece of evidence so far comes from a fake or
  an emulator. The first genuine proof is one signed-in family member
  opening the app and a second one seeing the change.
- **v2.2.0 is uncut.** Seventeen commits unreleased, including the APK split
  the owner's father needs. Now also including sync, which the deployed
  rules finally allow to work.
- **Q5** — nobody fluent has checked the sayings' spelling. Unchanged.
