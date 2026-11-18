# ADR-028 — The rules deploy with the release

**Status:** Accepted · **Date:** 2026-11-18 · **Deciders:** Developer, Owner
· **Builds on:** [ADR-018](ADR-018-release-branches-are-cut-from-main.md)
· **Fixes:** #146

## Context

`firestore.rules` has been tested against the Firestore emulator in CI since
Day 9. Thirty-four tests now, in a required check, on every pull request.

It reached the live project for the first time on 18 November, typed into a
terminal by the owner.

Those two facts had nothing to do with each other. A rules change could be
written, reviewed, tested by six required checks and merged, and the live
database would carry on serving whatever was last pushed by hand. CI proved
the **file** was right. Nothing had an opinion about what was **answering
requests**.

## Why it could not simply be checked

The first instinct was to probe the live database and compare. It does not
work, and the reason is the useful part.

After the deploy:

```
families           403
memberships        403
journals           403
not-a-collection   403
```

Before the deploy: the same four. The database was created in production
mode, so it refused everybody; the rules refuse an unauthenticated stranger
too. **From outside, a correct ruleset and no ruleset at all are
indistinguishable.**

That is not a flaw in the probe. It is the rules doing exactly their job,
and it means the only observer who could tell the difference is an
authenticated member of the family — which is to say, a real phone belonging
to a real person.

Reading the deployed source through the Firebase Rules API would answer it,
and needs a credential anyway. Having paid that price, the better thing to
buy with it is a deploy rather than an audit.

## Decision

**The rules deploy from the release workflow, after being tested on the
tagged commit, and the release cannot publish without them.**

- A `rules` job runs the emulator suite at the tag — not trusted from the
  pull request that merged it, because what is deployed must be what was
  tested at that exact revision.
- It then deploys to `mashibini-prayer`.
- `publish` lists it in `needs`, so no APK reaches a release page whose
  rules never went out.

What is live is then what was tested, by construction. There is nothing left
to compare, which is a better answer than a comparison.

## It fails rather than skips

The deploy needs a service account, and a workflow cannot create one. Until
the secret exists the release **fails**, at a step whose only job is to say
so and print the instructions.

The tempting alternative — `if: ${{ secrets.FIREBASE_SERVICE_ACCOUNT != '' }}`
— would produce a green release whose rules were never deployed. That is
#146 with an extra layer on top, and the retrospective already holds six
entries on checks that did not do their job. An eighth is not needed to
make the point.

## The ordering hazard, which no workflow can fix

Rules take effect the instant they are deployed. An APK reaches a phone
whenever somebody gets round to installing it. The two are days apart and
the gap is not controllable.

So:

| A rules change that… | Deploying first is… |
|:--|:--|
| **grants** access the new app needs | right — the app would be refused otherwise |
| **withdraws** access the old app uses | **wrong** — every installed copy breaks immediately |

The workflow deploys before publishing, which is correct for the first row
and dangerous for the second. That is a constraint on what a single rules
change may contain, not something ordering can solve: a withdrawal ships in
two releases, one that stops the app needing the access and a later one that
removes it.

Written down here because the failure is silent and remote. Nobody's build
goes red; the family's phones simply stop syncing, and the person who
deployed is not holding one of them.

## Consequences

**One credential, scoped to one job.** Firebase Rules Admin and nothing
else. It cannot read the family's data, and it should not be able to —
`docs/FIREBASE-SETUP.md` carries the five steps.

**The emulator suite runs twice per release.** Once on the pull request and
once on the tag. About a minute, for the only guarantee that matters here.

**The first live proof is still a phone.** This ADR makes deployment
trustworthy; it does not make sync *tested*. Everything about the live
database so far has been exercised against a fake or an emulator. The first
genuine evidence is a signed-in family member opening the app, and that is
listed as open in DAY-32 and DAY-33 rather than quietly assumed.
