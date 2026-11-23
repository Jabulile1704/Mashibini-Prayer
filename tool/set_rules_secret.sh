#!/usr/bin/env bash
#
# Puts a Firebase service-account key into the repository secret the release
# workflow reads (ADR-028, #163).
#
# The five written steps in docs/FIREBASE-SETUP.md were followed four times
# and the secret never appeared, because the half that happens in a browser
# and the half that happens on GitHub look like one task and are not. This
# script is the second half, and it refuses rather than succeeding quietly.
#
#   tool/set_rules_secret.sh [path/to/key.json]
#
# With no argument it looks for the newest plausible key in ~/Downloads.
#
# It never prints the key, and it does not delete the downloaded file — that
# is left to you, deliberately, so nothing of yours is removed by a script.

set -euo pipefail

REPO='Jabulile1704/Mashibini-Prayer'
SECRET='FIREBASE_SERVICE_ACCOUNT'
PROJECT='mashibini-prayer'

die() { echo "error: $*" >&2; exit 1; }

command -v gh >/dev/null || die "the GitHub CLI is not installed"
command -v python3 >/dev/null || die "python3 is not available"

KEY="${1:-}"

if [ -z "$KEY" ]; then
  # Newest first, and only files that actually look like a key.
  for candidate in $(ls -t "$HOME"/Downloads/*.json 2>/dev/null); do
    if python3 - "$candidate" <<'PY' >/dev/null 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if d.get('type') == 'service_account' else 1)
PY
    then
      KEY="$candidate"
      break
    fi
  done
fi

[ -n "$KEY" ] || die "no service-account key found in ~/Downloads.

The browser half has not been done. In the Google Cloud console:

  https://console.cloud.google.com/iam-admin/serviceaccounts?project=$PROJECT

  1. Create service account (any name; release-rules is clear)
  2. Grant it Firebase Rules Admin, and nothing else
  3. Open it, then Keys -> Add key -> Create new key -> JSON
  4. The file downloads. Run this script again.

Downloading the JSON is step 3's whole purpose. Creating the account
without it leaves nothing to upload, which is what happened four times."

[ -f "$KEY" ] || die "$KEY does not exist"

# Checked before it is sent, because a secret that is the wrong file fails
# on a tag rather than here.
python3 - "$KEY" "$PROJECT" <<'PY' || die "that file is not a key for this project"
import json, sys

path, project = sys.argv[1], sys.argv[2]
try:
    key = json.load(open(path))
except Exception as problem:
    print(f'  it is not valid JSON: {problem}', file=sys.stderr)
    sys.exit(1)

if key.get('type') != 'service_account':
    kind = key.get('type') or 'no "type" field'
    print(f'  it is "{kind}", not a service account.', file=sys.stderr)
    if 'project_info' in key or 'client' in key:
        print('  This looks like google-services.json, which is the app\'s'
              ' config and is already committed.', file=sys.stderr)
    sys.exit(1)

if key.get('project_id') != project:
    print(f'  it is for project "{key.get("project_id")}", not "{project}".',
          file=sys.stderr)
    sys.exit(1)

for field in ('private_key', 'client_email'):
    if not key.get(field):
        print(f'  it has no {field}, so it is not a complete key.',
              file=sys.stderr)
        sys.exit(1)

print(f'  key for {key["client_email"]}')
PY

echo "setting $SECRET on $REPO from $(basename "$KEY")"
gh secret set "$SECRET" --repo "$REPO" < "$KEY"

# The point of the exercise: say whether it is actually there.
if gh secret list --repo "$REPO" --json name --jq '.[].name' |
    grep -qx "$SECRET"; then
  echo "done — $SECRET is set."
  echo
  echo "Now delete the downloaded key; the secret should be the only copy:"
  echo "  rm '$KEY'"
else
  die "gh reported no error and the secret is not there. Check that you are
authenticated as somebody with admin on $REPO: gh auth status"
fi
