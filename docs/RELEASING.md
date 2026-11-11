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

That cuts `release/v1.1.0` **from `main`**, replays every non-merge commit
`develop` has gained since the last release onto it, bumps `pubspec.yaml`,
and drafts a `CHANGELOG.md` section from those commits' subjects.

**From `main`, not `develop`** (ADR-018). A branch cut from `develop`
carries the two back-merge commits made before ADR-015, and GitHub refuses
to rebase a branch containing a merge — so v1.1.0 and v1.2.0 both had to be
rebuilt by hand. Those two commits are in `develop`'s history permanently;
not making new ones does not remove them.

The script then checks `git diff develop` is empty. The release branch must
hold exactly `develop`'s code, because a missed commit would ship something
other than what was tested. It refuses to continue rather than producing a
branch that looks right.

If the replay conflicts, it aborts, removes the branch, and says to look for
a hotfix that landed on `main` and never came back.

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

**Then bring the release commit back to `develop` as a cherry-pick:**

```bash
git checkout develop && git pull
git cherry-pick $(git log main -1 --pretty=%H --grep='^chore(release): v1.1.0')
git push
```

**Never `git merge main`.** That was the rule until v1.0.1 and it does not
work here (ADR-015). Rebasing a release onto `main` makes copies of every
commit; merging `main` back brings those copies onto `develop` beside the
originals, which did three things:

- `develop` ended up holding the whole history twice — 148 commits, 76
  unique;
- the next release branch inherited the merge commit, and GitHub refuses to
  rebase a branch containing one, so **releases stopped being mergeable**;
- the changelog boundary stopped being computable from the tag.

The only thing `develop` needs from a release is the version bump and the
changelog entry — one commit. The code came from `develop` in the first
place.

If a fix was made *on* the release branch, cherry-pick that too. Forgetting
shows up immediately as the fix being missing from `develop`.

## Installing on a phone

iOS, with the phone plugged in and unlocked:

```bash
flutter devices
flutter run --release -d <device-id>
```

A free Apple account signs the build for **seven days**, after which the app
stops opening until it is installed again. That is Apple's limit on free
provisioning, not a problem with the build — see ADR-013.

Android: the APKs are attached to the GitHub Release, and there are two.

| File | Who it is for |
|:--|:--|
| `mashibini-prayer-<version>.apk` | Virtually every Android phone. `arm64-v8a` only, so roughly a third of the size |
| `mashibini-prayer-<version>-any-phone.apk` | The fallback, carrying every architecture. Take this one if the other says *App not installed* |

The unsuffixed name is the small one deliberately. `arm64-v8a` has been all
but universal on Android phones since 2017, and Assumption 1 already says
every member has a phone capable of running a current Flutter app. The
universal build stays because the failure it guards against — *App not
installed*, with no explanation — is one a family member cannot debug,
while a larger download is a much smaller problem.

**Both are checked against `android/release-key.sha256` before publishing.**
An unchecked artefact on a release page is #103 in a different costume: the
check still passes, and it is no longer checking what the family installs.

`--split-per-abi` also runs in the CI debug build, on every pull request. A
debug APK's size is nobody's problem; it is there so the flag is never
exercised for the first time during a release.

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

### The fingerprint is checked, not printed

`android/release-key.sha256` holds the SHA-256 of the certificate every
release so far has been signed with. `release.yml` reads the APK's actual
signing certificate and **fails the release** if it differs.

```bash
dart run tool/apk_signing_key.dart <apk> --expect "$(cat android/release-key.sha256)"
```

The same command works on a downloaded APK, on any machine, with no Android
SDK — which is how #103 was found.

Until v1.4.0 this was a `keytool -printcert -jarfile … || true` that printed
the owner and fingerprint to the log. It printed **nothing**, on every
release, and passed: `-jarfile` reads only the v1 JAR signature, and Flutter's
release APKs are signed v2/v3 with no v1 block at all. A guard that cannot
fail is worse than no guard, because it is believed.

If the check ever fails, stop. Every phone with the app installed is about to
be unable to update, and the only way through is uninstalling — which takes
that phone's rota and journal with it.

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
