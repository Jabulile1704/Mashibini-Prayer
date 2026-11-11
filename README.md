# Mashibini Prayer

A family keeps a prayer rota: each person takes a week to lead family prayer,
and when the last person's week ends it starts again. The rota lives in
everyone's head, which is why the handover gets remembered late.

This app holds the cycle, so nobody has to.

> **Status: in build.** Day 1 of a 14-day build. Nothing is installable yet.
> The plan, the requirements and the board are all public — see below.

## What it will do

| Screen | What it answers |
| --- | --- |
| **This week** | Whose week it is, who is next, and the day it changes hands |
| **Setup** | Who is in the family, in what order, and which weekday the week turns over |
| **Saying** | One African saying for the day, the same one for everybody |
| **Journal** | What you prayed about, private to you |

The rota is the product. The saying and the journal sit around it.

## Installing it

Android 7.0 or newer. The APKs are on the
[latest release](https://github.com/Jabulile1704/Mashibini-Prayer/releases/latest);
take the one without a suffix unless your phone says *App not installed*,
in which case take `-any-phone`.

## How this project is run

It is a small app built as though it were a production system, because the
process is half the point.

| Document | What is in it |
| --- | --- |
| [docs/CHARTER.md](docs/CHARTER.md) | Why it exists, who it is for, what is in and out of scope, who holds which gate |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Stories with acceptance criteria, non-functional requirements, open questions |
| [docs/SDLC.md](docs/SDLC.md) | The phases, the 14-day plan, and the working agreements |
| [docs/WORKFLOW.md](docs/WORKFLOW.md) | Branching model, commit convention, pull request rules, definition of done |
| [docs/daily/](docs/daily) | What happened each day, written at the end of it |

Work is tracked as [issues](https://github.com/Jabulile1704/Mashibini-Prayer/issues)
on the [project board](https://github.com/users/Jabulile1704/projects).
Nothing reaches `main` except through a pull request with a green build.

## Stack

Flutter and Dart on the front, Firebase behind it. The rota itself is pure Dart
with no I/O, so the part that must be correct can be tested without a device.

## Running it

Nothing to run yet. From Day 3:

```bash
flutter pub get
flutter test
flutter run
```
