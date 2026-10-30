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

# Where the last release ended, *on this branch*.
#
# Not the tag. Pull requests rebase onto `main` (ADR-007), so a tag on `main`
# shares no commits with the ones still sitting on `develop` — they are
# copies with different hashes. `git log v1.0.0..develop` therefore lists the
# entire project, and `git cherry` cannot help either, because the back-merge
# puts both copies on `develop` and leaves nothing on the other side to
# compare against.
#
# The back-merge commit is the honest boundary: everything behind it has
# shipped, everything after it has not. Found by running this script a second
# time and watching it offer the whole history as the changelog for a patch
# release.
PREVIOUS=$(git log --merges --grep='back into develop' --pretty=%H -1 2>/dev/null || echo '')
if [ -z "$PREVIOUS" ]; then
  PREVIOUS=$(git describe --tags --abbrev=0 2>/dev/null || echo '')
fi

echo "  from $CURRENT"
echo "    to $VERSION+$BUILD"
echo "  since $(git log -1 --pretty=%s "$PREVIOUS" 2>/dev/null || echo "the first commit")"
echo

git checkout -q develop
git pull -q --ff-only
git checkout -q -b "release/v$VERSION"

# The build number only ever goes up, across every release. Two builds that
# share a number are indistinguishable on a phone, which is the one thing a
# build number exists to prevent.
sed -i '' -E "s/^version: .*/version: $VERSION+$BUILD/" pubspec.yaml

RANGE="${PREVIOUS:+$PREVIOUS..}HEAD"
{
  echo "## [$VERSION] — $(date +%Y-%m-%d)"
  echo
  for section in "feat:Added" "fix:Fixed" "perf:Faster" "refactor:Changed"; do
    type="${section%%:*}"
    heading="${section##*:}"
    entries=$(git log "$RANGE" --no-merges --pretty=format:'%s' \
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
