# Day 30 — "Is my application secure?"

**Date:** 2026-11-10 · **Phase:** 9, the v1.1 backlog · **Roles on point:** Developer, DevOps, QA

## Planned

Nothing. The owner asked a question.

## Delivered

- **An authorisation flaw found and fixed** in the SAS Function (#133)
- **13 tests** for a Function that had none
- **A CVE gate** in CI, OSV-Scanner over every lockfile (#134)
- **5 high-severity advisories cleared** out of the rules test harness
- **N8 and N9**, which are the part most likely to matter in a year

## The answer was no

The honest answer to the question was that one security check existed — 28
Firestore rules tests, in CI since Day 9, genuinely good — and that it
guards **a database the app has never connected to**. There is no
`cloud_firestore` anywhere in `lib/`. The rules are preparation for sync,
not evidence about the shipped app.

Reading the rest of the code to answer properly found something.

## Authentication is not authorisation

`azure/sas-function/src/sas.ts` verified the caller's Firebase ID token
against Google's `tokeninfo`, and checked the audience was this project —
which is the part people usually leave out. Then it signed a SAS URL for
whatever blob name the query string asked for.

**The uid was used for exactly one thing: a log line.**

So any holder of a valid token for this project could mint a read URL for
any blob in the container, or a write URL to overwrite one. Google sign-in
admits any Google account, so "a valid token for this project" is very
nearly "anybody", not "a member of this family".

It had never been deployed, and nothing outside
`lib/src/data/sources/remote/` constructs a `RemoteFiles`. Wrong code, not
an exposure — which is why it went out as a normal PR rather than a
hotfix, on the owner's call once he confirmed the Function had never run.

### The fix, and why it is shaped the way it is

The caller no longer names the owner. `blobNameFor` **prepends** the uid the
request actually proved, so the blob is always `<uid>/<key>` and there is no
string a client can send that reaches another prefix.

That is why the test for `uid-sisi/a-song.mp3` asserts it lands at
`uid-jabulile/uid-sisi/a-song.mp3` rather than asserting a refusal. A
blocklist has to anticipate the input; making the bad input **inexpressible**
does not. The property test says it plainly: whatever the key, the name
begins with the caller's uid.

It narrows the spike, deliberately. **Nobody can read anybody else's files
now, including their own family's** — less than ADR-024 wanted, because the
Function cannot tell who is in which family. It holds a storage key;
membership is in Firestore, which it never reads. Widening it needs
membership a caller cannot forge, and that is a second rule rather than a
change to this one.

## Why nothing caught it

The Function had **no tests at all**, and that is the whole finding.

`test/data/remote_files_test.dart` is careful work. It covers the server
being unreachable, returning 500, and answering with a sign-in page — which
is what a lapsed Azure subscription actually returns. It asks, thoroughly,
what happens when the server **fails**. Nothing anywhere asked what happens
when it **succeeds**.

And **no requirement had been broken.** N3 names journal entries, in
Firestore, enforced by rules. This was files, in Blob Storage, behind a
Function. The requirement named a mechanism, so it covered that mechanism
and stopped.

So N8 was added, naming the decision instead of the mechanism:

> Anything that signs, grants or hands out access decides *what* the caller
> may reach, not only *whether* they are who they say.

It reaches the next place one of those decisions gets made, which N3 could
never have done.

## The CVE gate

Dependabot has raised update PRs since Day 1 and nothing was ever stopped by
ignoring one. An update PR is a suggestion. N9 is the gate.

**OSV-Scanner rather than `npm audit`**, because `npm audit` cannot see the
one that matters: the app is Dart, and `pubspec.lock` is the lockfile that
runs on a family's phone.

Checking before writing it was the right order. `test/rules` already had
**5 high-severity advisories**, all reaching `@grpc/grpc-js < 1.13.6`
through the Firebase test harness — and **there is no upgrade that fixes
it.** `@firebase/firestore@4.19.1`, the newest there is, pins
`@grpc/grpc-js@~1.9.0`. The harness moved to `firebase@13` anyway, and an
`overrides` entry forces 1.14.7, which is what actually clears it. An
override is the honest description: a dependency pins a version with a
published hole and we are refusing to run it.

### Two traps on the way

**The documentation was ahead of the repository.** Every OSV docs page
quotes `@v2.7.1`. That tag does not exist — the releases API says v2.7.0,
and `git/ref/tags/v2.7.1` is a 404. Copying the docs yields a workflow that
cannot resolve.

**A bad reusable-workflow call does not fail that job, it fails the file.**
The new job asked for `contents: read`; the called workflow declares
`actions: read`, `contents: read` and `security-events: write`. A caller
granting less is refused *before any job is created*, so the entire CI
workflow came back `startup_failure` and **none of the six required checks
ran at all**. One new job took static analysis, the tests, the rules and the
Android build down with it.

### Proving the gate was a gate

"No issues found" and "parsed nothing" produce the same green tick, and this
repository has been caught by that four times. So the override was removed
on purpose and the run watched.

It went red, named both advisories with their CVSS scores and fixed
versions — and the same run answered the question that mattered more:

```text
Scanned test/rules/package-lock.json file and found 120 packages
Scanned pubspec.lock file and found 125 packages
Scanned azure/sas-function/package-lock.json file and found 41 packages
```

**`pubspec.lock`, 125 packages.** The app's own Dart dependencies are
genuinely in scope. That was the entire argument for choosing OSV-Scanner
over `npm audit`, and it is now a fact rather than a claim.

The probe also settled the one risk that could not be tested on this laptop
— no JDK, as Day 9 recorded. The `Security rules` job passed with
`@grpc/grpc-js@1.14.7` forced under `@firebase/firestore@4.19.1`, and those
28 tests are the entirety of the grpc client usage here. The override does
not break the emulator.

## Where this leaves the honest answer

Better, and still not "secure".

| | |
|:--|:--|
| Firestore rules | 28 tests, CI, for a database the app does not use yet |
| SAS authorisation | 13 tests, CI |
| Dependencies | Gated, every lockfile, every PR |
| Static analysis for security | None |
| Anything running | Never tested |

The journal is plain JSON in `shared_preferences`. The OS sandbox and disk
encryption protect it on a normal phone, and it is not separately encrypted
— worth knowing, given the app tells the family "neither can we".

## A push that should not have worked

The correction above — removing the unmeasured "roughly 17 MB" from this
log — went **straight to `develop`**. No branch, no pull request, no review
of any kind. It worked.

`develop` requires six status checks and has done since Day 1. It also has
`enforce_admins: false`, which means the owner's account is exempt from all
of them. The checks apply to pull requests; a direct push is not a pull
request.

So the protection that this project has leaned on for thirty days protects
`develop` from everybody except the one person who commits to it.

CI did run afterwards, on the push, and the change was documentation. The
damage here is nil and the finding is not: **for thirty days, "every merge
to `develop` is analysed, tested and built by CI" (N6) has been a
convention rather than a constraint.** Every merge *was* — because every
change happened to go through a PR, not because anything required it.

It is the same shape as the morning's work, which is why it belongs in the
same log. The SAS Function checked who you were and not what you could
reach. Branch protection checks what a pull request contains and not
whether one was used.

Turning `enforce_admins` on is the owner's call, because it binds him too
— that being exactly the point — and it is listed below rather than done.

## Open

- **Whether the gate blocks.** A new job is not a required check until
  branch protection says so, and that is the owner's call.
- **Whether branch protection binds its owner.** `enforce_admins` is off on
  both `develop` and `main`. Until it is on, the six required checks are a
  convention.
- **Q5** — nobody fluent has checked the sayings' spelling. Unchanged.
- **The APK size is fixed but not yet measured.** Releases now publish an
  `arm64-v8a` build as the unsuffixed name, with the universal one kept as
  `-any-phone` for the "App not installed" case, and both are checked
  against the release key rather than only the one that used to exist.
  `--split-per-abi` is exercised on every pull request so a release is never
  its first run.

  No figure is claimed anywhere, because none has been measured. This
  machine has no JDK; CI's debug build proved the flag works and produced
  three APKs, but a debug build's 91 MB says nothing about a release. The
  real number arrives with the next tag, and belongs in that release's
  changelog rather than in a prediction written today.
