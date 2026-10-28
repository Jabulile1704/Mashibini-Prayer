# Firebase: what has to be done by hand

> **Status: part done.** The project exists and is configured; the apps are
> not registered yet and nothing in this repository talks to Firebase.

## Where the project actually is

| | |
|:--|:--|
| Project ID | `mashibini-prayer` |
| Project number | 647724958585 |
| Firestore | created 2026-10-28, **`africa-south1`** (Johannesburg), Standard edition |
| Sign-in | Google enabled |
| Plan | Spark — see [ADR-010](adr/ADR-010-the-free-tier-is-a-design-constraint.md) |
| Apps registered | **none yet** — this is the next step |
| Rules deployed | **not yet** — `firestore.rules` is written and tested, not pushed |

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

## The decision that has to come first

**Q3: does each member sign in as themselves, or does the family share one
install?**

This is not a preference. It decides what the rules can enforce:

| | Each member signs in | One shared install |
|:--|:--|:--|
| Rota sync across phones | Works | Works |
| Journal privacy (R4.2, N3) | Enforceable in the database | **Not enforceable** — one identity cannot be kept from itself |
| ADR-004 | Stands | **Superseded**: journals become device-local and unsynced, and the claim in the UI shrinks to match |
| Auth method | Email link or Google sign-in | Anonymous auth, one account |

Until this is answered, Day 8's rules cannot be written honestly, because
"only the author may read a journal entry" is either a rule or a fiction
depending on the answer.

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
   an unfinished app cannot leak anything in the meantime.
3. For location, pick the closest to South Africa that the console offers.
   There is no `africa-south1` for Firestore at the time of writing (ADR-001
   records this); `europe-west1` is the usual compromise. **The location cannot
   be changed afterwards**, so this is the one step worth pausing on.

### 3. Register the apps

Run from the repository root, once the Firebase CLI is installed
(`npm install -g firebase-tools`) and you are signed in (`firebase login`):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=mashibini-prayer
```

That writes `lib/firebase_options.dart`, plus `android/app/google-services.json`
and `ios/Runner/GoogleService-Info.plist`.

### 4. Tell git what not to commit

The generated files are not secrets in the usual sense — they identify the
project, they do not grant access to it, and security rules are what protect
the data. They are still configuration for *your* project rather than part of
the source, so add them to `.gitignore` and keep a copy somewhere safe:

```
lib/firebase_options.dart
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

CI builds will then need them supplied as secrets, or the Android build job
will need to skip the Firebase-dependent build. **That is a real decision this
document does not make for you**, and it should become an issue when the
project exists.

### 5. Tell me it is done

Once `flutterfire configure` has run, say so and the remaining wiring — the
Firestore source behind `RemoteFamilySource`, and the rules — can be written
against a project that actually exists.

## What will change in the repository afterwards

- `firebase_core` and `cloud_firestore` added to `pubspec.yaml`
- `FirestoreFamilySource` implementing the remote seam
- `SyncingFamilyRepository` composing local and remote through `FamilyMerge`
- `firestore.rules` and their tests (Day 8)
- The Android CI job taught how to build with, or without, the generated config

None of it touches the domain. That is what the seam was for.
