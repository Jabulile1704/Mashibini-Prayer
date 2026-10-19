# Project Charter — Mashibini Prayer

## Why this exists

The Mashibini family keeps a prayer rota. Each person takes a week to lead
family prayer, and when the last person's week ends the cycle starts again.
Today that rota lives in people's heads, which means the handover is remembered
late, or not at all.

This app holds the cycle so nobody has to.

## Vision

> One screen that answers "whose week is it?" without anyone having to ask.

Everything else — the daily verse, the prayer journal — sits around that answer.
If a feature does not serve the rota or the prayer life around it, it is out of
scope for v1.

## Success criteria

| # | Criterion | How it is measured |
|:--|:--|:--|
| S1 | The family stops asking whose turn it is | The four of us use it for a full cycle without needing to check with each other |
| S2 | The handover is never missed | A reminder lands before each new week starts |
| S3 | It works without a signal | The current week is readable with the phone in aeroplane mode |
| S4 | It survives being left alone | A member can be away for a week and the cycle still reads correctly on return |

## Stakeholders

| Stakeholder | Interest | Represented by |
|:--|:--|:--|
| Jabulile | Owner, developer, rota member | Himself |
| Little sister | Rota member | Product Owner persona, standing in until real feedback is gathered |
| Mom | Rota member | Product Owner persona |
| Dad | Rota member | Product Owner persona |

Real feedback from the family replaces the persona's judgement the moment it is
available. Anything the persona decided that the family later contradicts is a
defect in the requirement, not in the code.

## Team roles

This is a one-person project run as if it were a team. Each role is a distinct
responsibility with its own gate in the workflow — the point is that no change
reaches `main` without every one of these questions having been asked.

| Role | Owns | Gate it holds |
|:--|:--|:--|
| **Product Owner / Stakeholder** | Requirements, acceptance criteria, backlog priority | Does this solve the family's actual problem? |
| **Project Manager** | The 14-day plan, the board, scope control | Is this in scope, and is the board honest about where we are? |
| **Developer** | Implementation, code quality, ADRs | Does it work, and will the next person understand why it is written this way? |
| **QA / Tester** | Test strategy, test cases, the bug log | Is it proven to work, including when the inputs are hostile? |
| **Database Administrator** | Data model, schema, security rules, migrations | Is the data correct, minimal and protected? |
| **DevOps Engineer** | CI/CD, environments, releases, branch protection | Can we build, test and ship this repeatably, from a clean checkout? |

Role is recorded on each issue and PR by label (`role:po`, `role:pm`, `role:dev`,
`role:qa`, `role:dba`, `role:devops`), so the history shows which hat was on.

## Scope

**In scope for v1.0**

- The rota: who leads this week, who is next, when it changes hands
- Family setup: members, cycle order, the day the week turns over
- A verse for the day
- A prayer journal, private to the person who wrote it
- A reminder before each handover
- Offline-first: the phone is the source of truth for reading

**Out of scope for v1.0** (recorded so they are decisions, not oversights)

- Accounts for people outside the family
- Chat, comments or reactions
- Audio or video prayer recordings
- Multiple families or groups in one install
- Web or desktop builds

## Constraints

- **Platform**: Flutter, Android and iOS from one codebase
- **Backend**: Firebase, africa-south1 where the service offers it
- **Budget**: free tiers only
- **Team**: one person, roles rotated as above
- **Timeline**: 14 working days to v1.0.0
