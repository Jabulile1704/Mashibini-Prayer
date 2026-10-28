# ADR-011 — The Firebase config is committed to a public repository

**Status:** Accepted · **Date:** 2026-10-28 · **Deciders:** Owner, DevOps

## Context

`flutterfire configure` produces three files that identify the Firebase
project:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

This repository is public. `FIREBASE-SETUP.md` flagged on Day 7 that whether
to commit them was an open decision, and it stayed open until the files
existed.

It stopped being deferrable at that point for a mechanical reason: the Android
Gradle plugin that `flutterfire` installs **refuses to build without
`google-services.json`**. Not committing it means the Android CI job cannot
run, and that job has caught real problems.

## Decision

**Commit them.** The owner decided this on Day 11, with the reasoning below
put to them first.

## Why this is defensible

These are identifiers, not credentials. The API key in
`google-services.json` names the project; it does not authorise anything.
What decides whether a request may read or write is the security rules merged
on Day 9, which require a signed-in user who is a member of the family.

Firebase's own documentation takes this position, and committing these files
is the ordinary practice for Flutter projects.

## What is actually risked, and it is not the data

The honest risk is **quota**, not disclosure.

With the project id and API key public, anyone can direct requests at the
project. The rules refuse them — no family data is readable by a stranger, and
a journal entry is unreadable even by another family member. But a refused
request is still a request, and the project is on the Spark plan.

Enough traffic could exhaust a daily Firestore quota, at which point
**Firestore stops answering for the rest of that day**. There is no payment
method attached, so the failure is unavailability rather than a bill.

For a four-person family app that nobody is looking for, that is a small risk
taken knowingly. It would be the wrong trade for anything with users who are
not related to each other.

## Alternatives considered

| Option | Why not |
|:--|:--|
| **Gitignore, inject via CI secrets** | Nothing public, and real setup cost: a secret to create, a workflow step to decode it, and a thing to redo whenever it changes. Worth it for an app with strangers using it; not for this one. |
| **Gitignore, drop the Android CI build** | Simplest, and it discards the job that caught the Gradle/Maven 429 and would catch a broken plugin setup. Trading a working check for a risk that the rules already cover. |

## Consequences

**Good**

- CI builds from a clean checkout with no setup, which is what every other
  decision in this project has been trying to preserve.
- A fresh clone runs. No secrets to distribute to a future contributor, or to
  the owner on a new machine.

**Bad, and accepted**

- The project id and API keys are permanently in a public git history. Taking
  them back later means rotating the apps, not just deleting a file.
- A quota exhaustion attack is possible and cheap. Mitigation, if it ever
  happens: enable App Check, which is free on Spark, and would be the response
  rather than something to build now against a risk nobody has taken.
- This ADR must be revisited if the app ever leaves the family. The reasoning
  above rests entirely on who is using it.
