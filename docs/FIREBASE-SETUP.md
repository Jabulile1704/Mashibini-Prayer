# Firebase: what has to be done by hand

> **Status: done, and in use.** The project exists, both apps are
> registered, the rules are live, and since Day 32 the app reads and writes
> the family's document (#75). What is left is one credential — see
> [Deploying the rules](#deploying-the-rules) — so that the rules stop being
> deployed by hand.

## Where the project actually is

| | |
|:--|:--|
| Project ID | `mashibini-prayer` |
| Project number | 647724958585 |
| Firestore | created 2026-10-28, **`africa-south1`** (Johannesburg), Standard edition |
| Sign-in | Google enabled |
| Plan | Spark — see [ADR-010](adr/ADR-010-the-free-tier-is-a-design-constraint.md) |
| Apps registered | both — `firebase.json` names the Android and iOS app ids |
| Rules deployed | **yes**, first on 2026-11-18, by hand. Automated from the next release — see below |
| Sign-in | Google, and `request.auth.uid` is load-bearing since Day 32 |

`africa-south1` is better than this project expected. ADR-001 assumed Firestore
had no South African region and accepted the latency and the POPIA question as
a cost; that assumption was wrong and has been corrected. The family's data
stays in the country.

## Why this is not already done

Creating a Firebase project requires signing in to a Google account. That is
the owner's account, not something the build can do on anyone's behalf, and
faking it — stubbing a fake project id, committing a placeholder
`google-services.json` — would produce a repository that looks finished and
fails on the first real device.

So the data layer was built to the seam instead. Everything above
`RemoteFamilySource` is written and tested; the implementation behind it waits
on a project existing.

## What is already in place

| Piece | State |
|:--|:--|
| Local storage and the read path | Done (ADR-003, ADR-006) |
| `FamilyRepository` seam | Done — nothing above it mentions Firestore |
| Merge and conflict policy | Done and tested (ADR-008) |
| Collision-safe ids | Done (ADR-008) |
| Firestore schema design | Done (`DATA-MODEL.md`) |
| Security rules | **Day 8** |
| Firebase project, app registration, wiring | **This document** |

## The decision that had to come first — answered

**Q3: does each member sign in as themselves, or does the family share one
install?** Answered on Day 11: each person signs in as themselves
([ADR-023](adr/ADR-023-each-person-signs-in-as-themselves.md)). The table is
kept because it is the reason, not because the question is still open.

It was never a preference. It decides what the rules can enforce:

| | Each member signs in | One shared install |
|:--|:--|:--|
| Rota sync across phones | Works | Works |
| Journal privacy (R4.2, N3) | Enforceable in the database | **Not enforceable** — one identity cannot be kept from itself |
| ADR-004 | Stands | **Superseded**: journals become device-local and unsynced, and the claim in the UI shrinks to match |
| Auth method | Email link or Google sign-in | Anonymous auth, one account |

Until it was answered, Day 8's rules could not be written honestly, because
"only the author may read a journal entry" is either a rule or a fiction
depending on the answer. It is a rule.

## Before you click anything: the free plan has teeth

The project stays on **Spark**, the no-cost plan. Checked against Firebase's
own pages, not from memory — the full write-up is
[ADR-010](adr/ADR-010-the-free-tier-is-a-design-constraint.md). Three things
matter while you are in the console:

1. **Do not enable email-link (passwordless) sign-in.** It is capped at
   **five emails per day for the whole project**. Four people, one of them
   retrying on a bad evening, and nobody can sign in. If you want individual
   accounts, use **Google sign-in** or **email and password**.
2. **Phone/SMS sign-in is not available** on Spark at all.
3. **Do not link a billing account**, accept the $300 trial credit, or enable
   a paid Google Cloud API in this project. Any of those **auto-upgrades it to
   Blaze**, which is how a free project quietly becomes a billable one.

Cloud Functions and Cloud Storage are also unavailable on Spark. The app is
built not to need either — see ADR-010 — so there is nothing for you to work
around, but it is why the rota will never send a notification to anybody
else's phone.

## Steps

Roughly twenty minutes. Nothing here needs a card.

### 1. Create the project

1. Go to <https://console.firebase.google.com> and sign in.
2. **Add project**, name it `mashibini-prayer`.
3. Disable Google Analytics — this app sends no analytics, and N4 says collect
   only what the app needs.

### 2. Choose a Firestore location

1. **Build → Firestore Database → Create database**.
2. Start in **production mode**. The rules land on Day 8; starting locked means
   an unfinished app cannot leak anything in the meantime. This is what the
   project did, and it is why a stranger's request was refused for the three
   weeks before the rules existed as well as after.
3. For location, pick the closest to South Africa that the console offers.
   ADR-001 assumed there was no `africa-south1` for Firestore and accepted
   the latency as a cost; that was wrong, and this project is in
   **`africa-south1`** (Johannesburg). **The location cannot be changed
   afterwards**, so this is the one step worth pausing on.

### 3. Register the apps

Run from the repository root, once the Firebase CLI is installed
(`npm install -g firebase-tools`) and you are signed in (`firebase login`):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=mashibini-prayer
```

That writes `lib/firebase_options.dart`, plus `android/app/google-services.json`
and `ios/Runner/GoogleService-Info.plist`.

### 4. The generated files are committed — decided, not defaulted

`lib/firebase_options.dart`, `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` are **in the repository**, which is
public.

They identify the project; they do not authorise anything. The security rules
decide access. The risk that is real is quota exhaustion rather than
disclosure, and it was accepted knowingly for a four-person family app — see
[ADR-011](adr/ADR-011-the-firebase-config-is-committed.md) for the full
reasoning and what would change the answer.

### 5. Done

Everything in the list that used to be here has been built:

| | |
|:--|:--|
| `firebase_core`, `firebase_auth`, `cloud_firestore` in `pubspec.yaml` | Days 11 and 32 |
| `FirestoreFamilySource` behind the remote seam | Day 32 |
| `SyncingFamilyRepository`, composing local and remote through `FamilyMerge` | Day 32 |
| `firestore.rules` and 34 tests against the emulator | Day 9 onwards |
| The Android CI job building with the committed config | Day 11 |

None of it touches the domain. That is what the seam was for.

## Deploying the rules

The rules were pushed to the live project for the first time on
**2026-11-18**:

```bash
firebase deploy --only firestore:rules --project mashibini-prayer
```

That worked, and it is the wrong way to do it. CI has tested
`firestore.rules` against the emulator since Day 9; the live database serves
whatever was last pushed from somebody's laptop. The two facts were
unconnected, and **nothing in this repository could observe the gap** —
see #146 and
[ADR-028](adr/ADR-028-the-rules-deploy-with-the-release.md).

From the next release, `.github/workflows/release.yml` runs the rules suite
on the tagged commit and then deploys. `publish` depends on it, so a release
cannot ship an APK whose rules never went out.

### The one thing still needed by hand

A service account, because a workflow cannot sign in as a person.

1. [Google Cloud console → Service accounts](https://console.cloud.google.com/iam-admin/serviceaccounts?project=mashibini-prayer)
   → **Create service account**. Any name; `release-rules` is a clear one.
2. Grant it **Firebase Rules Admin** (`roles/firebaserules.admin`). It needs
   nothing else — it is not for reading data, and it should not be able to.
3. **Keys → Add key → JSON.** Download it.
4. Repository → **Settings → Secrets and variables → Actions → New
   repository secret**, named exactly `FIREBASE_SERVICE_ACCOUNT`, with the
   whole JSON file as the value.
5. Delete the downloaded file. The secret is the only copy that should exist.

Until that secret exists, **the release fails** at the "service account is
present" step with those instructions. That is deliberate: a deploy step
that quietly does nothing when its credential is missing is the bug in #146
with an extra layer on top.

### The ordering hazard

Rules take effect the moment they are deployed. An APK reaches a phone
whenever somebody gets round to installing it.

So a rules change that **removes** access breaks every already-installed
copy immediately, and the release that makes it correct arrives days later.
Deploying before publishing — which is what the workflow does — is right for
rules that grant access and wrong for rules that withdraw it.

That is a constraint on what a rules change may contain, not something a
workflow can fix. A withdrawal has to ship in two releases: one that stops
the app needing the access, and a later one that removes it.
