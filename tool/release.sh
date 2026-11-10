#!/usr/bin/env bash
# Cuts a release branch, bumps the version, and drafts the changelog entry.
#
# Everything this does by hand is a thing somebody forgets at 11pm: the
# version in two places, the changelog heading, the branch name. It does not
# tag and does not push — those are decisions, and a script should not make
# decisions on somebody's behalf. See docs/RELEASING.md.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: tool/release.sh <version>    e.g. tool/release.sh 1.1.0" >&2
  exit 64
fi

VERSION="$1"
if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: '$VERSION' is not a semantic version like 1.2.3" >&2
  exit 64
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is not clean" >&2
  exit 1
fi
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "error: tag v$VERSION already exists" >&2
  exit 1
fi

CURRENT=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
BUILD=$((${CURRENT##*+} + 1))

# `main` has to be current before the boundary can be worked out from it.
# This used to happen further down, just before the branch was cut.
git fetch -q origin main

# Where the last release ended, *on this branch*.
#
# Not the tag. Pull requests rebase onto `main`, so a tag on `main` shares no
# commits with the ones on `develop` — they are copies with different hashes,
# and `git log v1.0.0..develop` lists the entire project.
#
# And **not** the last `chore(release):` commit either, which is what this
# used until v2.1.0. That marker records where `develop` was when somebody
# remembered to cherry-pick it back — the same thing as the release only if
# the cherry-pick was immediate. v2.0.0's was not. Three commits had already
# landed on `develop` (sign-in, its settings row, and the artefact cleanup),
# so the marker came to rest *above* work that had never been released.
#
# The next release would have replayed 9 commits instead of 18 and shipped
# without the songbook, without sign-in and without a Firestore rules fix.
# Nothing would have failed: the tests pass on either set, `git diff develop`
# was never consulted against the right baseline, and the changelog is drafted
# from the same wrong list. It would have been found by a family noticing a
# feature had vanished.
#
# So the boundary is computed from **content**, which cannot drift out of
# step with itself: walk `develop`'s own line and find the newest commit whose
# tree `main` already has. CHANGELOG.md and pubspec.yaml are excluded because
# the release commit is precisely the thing that may differ between the two at
# that point.
MAIN=$(git rev-parse origin/main)
PREVIOUS=''
for candidate in $(git log --first-parent develop --pretty=%H -500); do
  if [ -z "$(git diff --name-only "$candidate" "$MAIN" -- . \
      ':(exclude)CHANGELOG.md' ':(exclude)pubspec.yaml')" ]; then
    PREVIOUS="$candidate"
    break
  fi
done

# No match means `main` holds something `develop` does not — a hotfix that
# never came back, most likely. Refusing is the whole point: the old code
# guessed here, and the guess is how nine commits nearly went missing without
# a word being said about it.
if [ -z "$PREVIOUS" ]; then
  echo "error: nothing on develop has the content main already holds." >&2
  echo "       main carries work develop does not. Look for a hotfix that" >&2
  echo "       landed on main and was never brought back, cherry-pick it to" >&2
  echo "       develop, and run this again." >&2
  exit 1
fi

# The work to ship: everything on develop since the last release, merges
# excluded. These are what get replayed onto main.
WORK=$(git log "${PREVIOUS:+$PREVIOUS..}develop" --no-merges --reverse --pretty=%H)
if [ -z "$WORK" ]; then
  echo "error: nothing on develop since the last release" >&2
  exit 1
fi

echo "  from $CURRENT"
echo "    to $VERSION+$BUILD"
echo "  since $(git log -1 --pretty=%s "$PREVIOUS" 2>/dev/null || echo "the first commit")"
echo "  $(printf '%s\n' "$WORK" | wc -l | tr -d ' ') commits to replay"
echo

# **Cut from main, not develop** (ADR-018).
#
# A branch cut from develop carries the two back-merge commits made before
# ADR-015, and GitHub refuses to rebase a branch containing a merge — so
# every release since v1.0.1 had to be rebuilt by hand on main. Those two
# commits are in develop's history permanently; no amount of not making new
# ones removes them.
#
# Replaying the work onto main is what the hand-rebuild did twice. This is
# that, done by the script instead of from memory at eleven at night.
git checkout -q -b "release/v$VERSION" origin/main

if ! git cherry-pick $WORK >/dev/null 2>&1; then
  git cherry-pick --abort 2>/dev/null || true
  git checkout -q develop
  git branch -q -D "release/v$VERSION"
  echo "error: could not replay develop's work onto main cleanly." >&2
  echo "       main has diverged from develop by more than a release." >&2
  echo "       Resolve by hand, or check whether a hotfix landed on main." >&2
  exit 1
fi

# The invariant that makes this safe: the release branch must now hold
# exactly develop's code. If it does not, a commit was missed and the
# release would quietly ship something other than what was tested.
if [ -n "$(git diff develop --stat)" ]; then
  echo "error: the release branch does not match develop:" >&2
  git diff develop --stat >&2
  echo "       Refusing to continue — this would ship untested code." >&2
  exit 1
fi

# The build number only ever goes up, across every release. Two builds that
# share a number are indistinguishable on a phone, which is the one thing a
# build number exists to prevent.
sed -i '' -E "s/^version: .*/version: $VERSION+$BUILD/" pubspec.yaml

# The replayed commits, not a range. `$PREVIOUS` is a commit on develop and
# the branch is now cut from main, so it is not an ancestor of HEAD and
# `$PREVIOUS..HEAD` would list the whole project again — the exact bug #70
# was filed for, reappearing from the other side.
#
# `$WORK` is already the right set: it is what was replayed.
{
  echo "## [$VERSION] — $(date +%Y-%m-%d)"
  echo
  for section in "feat:Added" "fix:Fixed" "perf:Faster" "refactor:Changed"; do
    type="${section%%:*}"
    heading="${section##*:}"
    entries=$(git log --no-walk=unsorted $WORK --pretty=format:'%s' \
      | grep -E "^$type(\([a-z0-9._-]+\))?!?: " \
      | sed -E "s/^$type(\([a-z0-9._-]+\))?!?: /- /" || true)
    if [ -n "$entries" ]; then
      echo "### $heading"
      echo
      echo "$entries"
      echo
    fi
  done
} > /tmp/changelog-entry.md

if [ -f CHANGELOG.md ]; then
  # Below the preamble, above the previous release.
  awk 'NR==FNR { entry = entry $0 "\n"; next }
       !done && /^## \[/ { printf "%s", entry; done = 1 }
       { print }
       END { if (!done) printf "\n%s", entry }' \
    /tmp/changelog-entry.md CHANGELOG.md > /tmp/changelog.md
  mv /tmp/changelog.md CHANGELOG.md
else
  cat /tmp/changelog-entry.md > CHANGELOG.md
fi

echo "On release/v$VERSION:"
echo "  - pubspec.yaml  → $VERSION+$BUILD"
echo "  - CHANGELOG.md  → a drafted [$VERSION] section"
echo
echo "Read the changelog and edit it. Commit messages are written for"
echo "reviewers; a changelog is written for the family. Then:"
echo
echo "  git add -A && git commit -m 'chore(release): v$VERSION'"
echo "  git push -u origin release/v$VERSION"
echo "  gh pr create --base main --title 'chore(release): v$VERSION'"
echo
echo "The branch was cut from main and replays develop's work onto it, so"
echo "it can be rebase-merged (ADR-018). After it merges and the tag is"
echo "pushed, bring the release commit back to develop as a cherry-pick —"
echo "never a merge (ADR-015):"
echo
echo "  git checkout develop && git pull"
echo "  git cherry-pick \$(git log main -1 --pretty=%H --grep='^chore(release): v$VERSION')"
echo "  git push"
