# ADR-007 — `develop` is the default branch, and pull requests rebase

**Status:** Accepted · **Date:** 2026-10-23 · **Deciders:** DevOps, PM

## Context

This project is run as a deliberate exercise, and one of its stated purposes is
a visible, honest record of daily work. On Day 6 the owner noticed GitHub
reporting **two contributions** for a day that produced seven commits across
two merged pull requests.

The cause was not the work. It was where the work lands:

1. **GitHub counts commits towards the contribution graph only on the
   repository's default branch** (or `gh-pages`). The default was `main`, and
   under the branching model in `WORKFLOW.md` `main` receives nothing but
   releases. It held exactly one commit — the initial one. Sixteen commits sat
   on `develop`, counted as zero.
2. **Squash merging collapses a branch into one commit.** Even once the first
   problem was fixed, a day of six commits would appear as one per pull
   request.

Measured rather than assumed, via the contributions API:

| Repository | Commits counted that week |
|:--|--:|
| JM-Mashibini-Website-Portfolio | 7 |
| Jabulile1704 | 2 |
| Yetsa | 1 |
| **Mashibini-Prayer** | **0** |

## Decision

1. **`develop` becomes the default branch.** `main` keeps its role exactly:
   release commits only, reached through a `release/*` or `hotfix/*` branch,
   which the PR hygiene workflow still enforces.
2. **Pull requests are rebase-merged**, not squashed. Squash and merge-commit
   are both disabled at the repository level, so the convention cannot be
   forgotten.

## Why not the alternatives

| Option | Why not |
|:--|:--|
| **Merge `develop` into `main` daily** | Makes `main` a running log rather than a list of releases, which is the one thing the branching model says it is not. It would also need merge commits, which the linear-history rule forbids. |
| **Merge commits instead of rebase** | Would also put every commit on the default branch, but `required_linear_history` is enabled on both branches — deliberately — and a merge commit per story would end that. Rebase gives the same visibility and keeps history linear. |
| **Leave it and accept the count** | Defensible if the graph were vanity. It is not: an accurate record of when work happened is one of this project's deliverables, and a graph that under-reports by 90% is simply wrong. |

## Consequences

**Good**

- Commits count, and each one counts separately. A day's work appears as the
  number of commits actually written.
- Individual commit messages survive into `develop`. This repository's commit
  bodies explain *why*, and squashing was discarding them into a merge summary.
- `git log develop` becomes a real narrative of the project rather than one
  line per story.

**Bad, and accepted**

- `develop`'s history is longer and more granular. `WORKFLOW.md` previously
  justified squashing as making the branch "read as one commit per story";
  that readability is traded for a truthful record, and the pull request still
  groups the commits for anyone who wants the story-level view.
- A rebase rewrites commit hashes, so a branch that someone else had checked
  out would need re-fetching. With one contributor this costs nothing.
- GitHub's own `Closes #n` auto-close now fires for pull requests into
  `develop`, because it is the default branch. `close-linked-issues.yml`
  becomes belt-and-braces. It is left in place: it costs one job, and it is
  what keeps the behaviour working if the default branch ever moves back.

**Note on what this does not do**

Changing the default branch did **not** retroactively credit the sixteen
commits already on `develop` at the time of the change. The contribution graph
was re-checked immediately afterwards and still reported zero for this
repository. Future commits count; the first six days do not appear to.
