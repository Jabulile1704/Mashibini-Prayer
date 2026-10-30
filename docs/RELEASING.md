# Releasing

One page, because a release process nobody can remember is a release process
that gets skipped.

## The shape of it

A release is a **tag on `main`**. Everything else follows from that:
`release.yml` fires on `v*`, checks the tag against `pubspec.yaml` and the
changelog, builds, and publishes a GitHub Release with the changelog section
as its notes.

There is deliberately no way to publish without tagging, and no way to tag
without publishing. The tag *is* the decision.

## Versioning

[Semantic Versioning](https://semver.org), as `MAJOR.MINOR.PATCH+BUILD`.

| Part | Goes up when |
|:--|:--|
| **MAJOR** | A family would have to do something differently, or stored data changes shape in a way an older build cannot read |
| **MINOR** | Something new that nobody has to learn about to keep using the app |
| **PATCH** | Something that was wrong is now right |
| **BUILD** | Every single time, forever |

The build number never resets and never repeats, across any version. Two
builds sharing a number are indistinguishable on a phone, which is the one
thing a build number exists to prevent. `tool/release.sh` increments it from
whatever is in `pubspec.yaml`, so it keeps climbing whether the version went
up by a patch or a major.

The version is visible at the foot of the home screen, so "which build is on
this phone?" can be answered by looking at the phone.

**The version is bumped on the release branch, never on a feature branch.**
Two features merged in either order would otherwise each claim a version.

## Cutting one

```bash
tool/release.sh 1.1.0
```

That cuts `release/v1.1.0` from an up-to-date `develop`, bumps
`pubspec.yaml`, and drafts a `CHANGELOG.md` section from the Conventional
Commit subjects since the last release.

"Since the last release" means **since the back-merge commit**, not since the
tag. Pull requests rebase onto `main`, so a tag on `main` shares no commits
with the ones on `develop` — they are copies with different hashes, and
`git log v1.0.0..develop` lists the entire project.

**Then read the changelog and rewrite it.** A commit subject is written for a
reviewer; a changelog entry is written for the family. "feat(rota): pass over
a turn" becomes "You can now skip somebody's week when they are away." The
script drafts, it does not author.

```bash
git add -A && git commit -m "chore(release): v1.1.0"
git push -u origin release/v1.1.0
gh pr create --base main --title "chore(release): v1.1.0"
```

A release branch is the one branch allowed to target `main` — `pr-hygiene.yml`
enforces that the other way round, by refusing everything else.

## Shipping it

Once the PR is green and merged:

```bash
git checkout main && git pull
git tag -a v1.1.0 -m "v1.1.0"
git push origin v1.1.0
```

The tag triggers the release. Watch it with `gh run watch`.

**Then merge `main` back into `develop`**, so the version bump and any
release fixes are not stranded on `main`:

```bash
git checkout develop && git pull
git merge --no-ff main -m "chore: merge v1.1.0 back into develop"
git push
```

This is the one merge in this repository that is not a rebase. A release is a
join of two histories and the merge commit is the record of it.

## Installing on a phone

iOS, with the phone plugged in and unlocked:

```bash
flutter devices
flutter run --release -d <device-id>
```

A free Apple account signs the build for **seven days**, after which the app
stops opening until it is installed again. That is Apple's limit on free
provisioning, not a problem with the build — see ADR-013.

Android: the APK is attached to the GitHub Release.

## The Android signing key

Android identifies an app by package name **and** signing key. A build signed
by a different key will not install over the previous one — and since
everything here is kept on the phone, the only way through is an uninstall
that takes somebody's rota and prayer journal with it.

So there is one stable key, and it never changes. Its job is continuity, not
provenance: nobody verifies it and no store checks it (ADR-014).

It lives in three repository secrets:

| Secret | What |
|:--|:--|
| `ANDROID_KEYSTORE_BASE64` | the PKCS#12 keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | its password |
| `ANDROID_KEY_ALIAS` | the key's alias — `mashibini` |

`release.yml` **fails** when any of them is missing rather than falling back
to a debug key, because a silent fallback is exactly the bug this replaced.

Each release prints the certificate's owner and SHA-256 fingerprint in the
build log. If that fingerprint ever changes between releases, stop: every
phone with the app installed is about to be unable to update.

### Building one locally

With the keystore on disk, put an `android/key.properties` beside it:

```properties
storeFile=upload-keystore.p12
storePassword=…
keyAlias=mashibini
keyPassword=…
```

Both the file and `*.p12` are gitignored. **Never commit either.**

### If the key is lost

There is no recovery. Every phone with the app installed has to uninstall
before it can take another update, and uninstalling loses that phone's
journal, rota and settings.

Keep a copy somewhere that is not this repository and not this laptop. It is
a 4KB file that cannot be regenerated.

## What a release still does not do

It does not sign for distribution. There is no App Store presence and no paid
Apple Developer account, so there is no identity that means anything to
anyone outside the family. ADR-013 records that reasoning; ADR-014 records
the one job a signature does have here, which is letting Android recognise
the next build as the same app.
