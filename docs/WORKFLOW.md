# Workflow — branches, commits, pull requests

## Branching model

A trimmed Git Flow. Two long-lived branches, everything else short-lived.

```
main       ──●────────────────────────●──────────────●──   tagged releases only
              ╲                      ╱              ╱
develop    ────●──●──●──●──●──●──●──●──────●──●──●─●───    always green
                ╲ ╱    ╲ ╱    ╲ ╱           ╲ ╱
feature/*        ●      ●      ●             ●             one story each
```

| Branch | Cut from | Merges into | Lives for |
|:--|:--|:--|:--|
| `main` | — | — | forever; every commit is a release |
| `develop` | `main` | `main` via a release branch | forever; integration |
| `feature/<id>-<slug>` | `develop` | `develop` | one story |
| `fix/<id>-<slug>` | `develop` | `develop` | one defect |
| `chore/<slug>` | `develop` | `develop` | tooling, docs, CI |
| `release/vX.Y.Z` | `develop` | `main` **and** `develop` | one release |
| `hotfix/vX.Y.Z` | `main` | `main` **and** `develop` | one emergency |

The story ID goes in the branch name: `feature/R1.1-whose-week-is-it`.

**Nothing is committed directly to `main` or `develop`.** Both are protected and
take changes only through a pull request with a passing build.

## Commits

[Conventional Commits](https://www.conventionalcommits.org), because the
changelog is generated from them and because the type is the fastest way to see
what a commit was trying to do.

```
<type>(<scope>): <subject>

<body: why, not what — the diff already says what>

Refs: #<issue>
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`.

- Subject in the imperative, under 72 characters, no trailing full stop.
- One logical change per commit. If the body needs the word "and", it is probably two commits.
- A commit that only passes CI because of an unrelated change does not belong in the same commit.

## Pull requests

Every PR must:

1. Target `develop` (or `main`, only from a `release/*` or `hotfix/*` branch).
2. Name the story or defect it closes, so the board moves itself.
3. Pass CI — analyse, test, build.
4. Carry a `role:*` label saying which hat the work was done under.
5. Describe how it was verified. "It builds" is not verification.

PRs are squash-merged into `develop` so the branch reads as one commit per
story, and the feature branch is deleted on merge.

### Review

A one-person project still gets a review, performed with a different hat on
from the one that wrote the code: the QA role reviews a `role:dev` PR against
the story's acceptance criteria, the DBA role reviews anything touching the data
model or rules, and DevOps reviews anything in `.github/`. The review is written
into the PR as a comment, not left implicit.

## Definition of Done

A story is done when all of these are true:

- [ ] Every acceptance criterion has a passing automated test, or a QA note on the issue saying why it cannot be automated and how it was checked instead
- [ ] `flutter analyze` is clean — no new warnings, none suppressed without a comment saying why
- [ ] New logic has unit tests; new screens have at least one widget test
- [ ] Docs updated if behaviour or data shape changed
- [ ] The PR is merged into `develop` and the branch deleted
- [ ] The board card is in **Done** and the issue is closed by the merge, not by hand

## Versioning

[Semantic Versioning](https://semver.org). Until v1.0.0 the app is `0.x`, and
`0.x` minor bumps may still change behaviour. The version lives in
`pubspec.yaml` and is bumped on the release branch, never on a feature branch.

## A note on issue closing

GitHub only auto-closes a linked issue when the pull request merges into the
**default** branch. Every PR here merges into `develop`, so the keyword in the
PR body does nothing on its own.

`.github/workflows/close-linked-issues.yml` fills the gap: on a merged PR into
`develop` it reads `Closes #n` / `Fixes #n` / `Resolves #n` out of the body and
closes those issues with a comment pointing back at the PR. The board's own
"item closed → Done" automation then moves the card.

So the rule stands — **close issues by merging, never by hand** — it is just
this repository that has to implement it rather than GitHub.
