# Test strategy

> Phase 5. Written on Day 3, alongside the first code, because a test strategy
> written after the tests is a description, not a strategy.

## What this app is actually risking

Not every part of this app can fail in the same way, so not every part earns
the same testing.

| If this breaks | The family experiences | So it is tested |
|:--|:--|:--|
| The rota engine | The app confidently names **the wrong person**, and someone is embarrassed in front of their family | Exhaustively, by unit tests, including ten years of weeks |
| Persistence | Setup is lost, or the app opens empty | Unit tests against fakes, plus a real round-trip |
| A screen's layout | It looks wrong but still says the right name | One widget test per screen, then eyes |
| The verse of the day | A different verse than intended | Lightly — being wrong here is a disappointment, not a failure |

The rota is the only part that can be *confidently wrong*, which is the worst
failure mode an app like this has. That is where the tests concentrate.

## The shape of it

```
            ╱╲          manual — a real phone, before a release
           ╱  ╲         few, scripted in the release checklist
          ╱────╲
         ╱      ╲       widget — one screen at a time, no network
        ╱        ╲      some
       ╱──────────╲
      ╱            ╲    unit — pure Dart, no Flutter binding, no clock
     ╱______________╲   most
```

Deliberately bottom-heavy. The domain has no I/O and takes the date as an
argument (ADR-002, ADR-005), so the interesting cases are *cheap*: "ten years
of weeks" is a loop, not a fixture.

## What each level is for

**Unit** — `test/domain/`. Pure Dart. No `WidgetTester`, no bindings, no
network, no clock. Every acceptance criterion with a definite input and output
belongs here. These run in under a second, so there is no excuse for not
running them.

**Widget** — `test/presentation/`. One screen, pumped with a fake repository.
Asserts what a person would see: the leader's name is on screen, the empty
state says what is wrong, the error state is not a blank page. It does not
re-test the rota — that is settled a layer down.

**Manual** — the release checklist. Reserved for what cannot be automated
honestly: how it looks at the largest font size, whether a real notification
arrives, and whether the app survives the OS killing it (N7).

## When a test is done

A test is not finished because it passes. It is finished when:

1. **It can fail.** If you have not seen it red, you do not know what it
   watches. Break the code deliberately once.
2. **Its name says the behaviour**, not the method. `a skipped member is not
   owed a double turn later` — not `testSkip2`.
3. **It asserts the behaviour, not the implementation.** Renaming a private
   method must not break a test.
4. **A failure message is enough to diagnose it.** Where the assertion is a
   set or a long list, pass a `reason:` with the actual data in it.

## Coverage

A number is not a goal, except where it is:

| Area | Expectation |
|:--|:--|
| `lib/src/domain/` | **100% of lines and branches.** It is pure, it is small, and it is the part that can be confidently wrong. Anything uncovered here is either untested or dead; both need action. |
| `lib/src/data/` | High. Our own logic against fakes; a vendor wrapper against the **vendor's own** in-memory implementation where one exists. |
| `lib/src/presentation/` | No target. One meaningful widget test per screen beats a high number made of pumping widgets and asserting nothing. |

CI uploads `coverage/lcov.info` on every run. **No threshold fails the build
yet** — one introduced before there is much code only teaches you to game it.
It should be added once the domain is complete, and that is a Day 12 item.

## Vendor code: a distinction worth making

"Do not mock a vendor SDK" and "do not test the code that talks to it" are not
the same rule, and conflating them left a real gap on Day 4.

**Do not** hand-write a double that encodes our *guess* at how a package
behaves. The test then proves the code matches the guess, and passes just as
happily when the guess is wrong.

**Do** use the package's own in-memory implementation when it ships one.
`shared_preferences_platform_interface` provides `InMemorySharedPreferencesAsync`,
which is the maintainers' implementation of their own interface — no guess of
ours is encoded in it.

The difference matters because the wrapper is exactly where a wiring mistake
hides: a wrong key, a value written but never read back, an API used
incorrectly. Every test above the seam would still pass, and the family would
open the app one morning to "no rota set up".

Proven rather than asserted: writing under a different key fails 6 tests, and
a `delete` that does nothing fails 2.

Where a package ships no such implementation — Firestore, for instance — the
wrapper stays thin enough to read in one sitting and is covered by integration
instead.

## Defects

Severities, matching `.github/ISSUE_TEMPLATE/defect.yml`:

| | Meaning | Example |
|:--|:--|:--|
| **S1** | The rota shows the wrong person | The leader is off by one after a skip |
| **S2** | A feature is unusable, no workaround | Setup cannot be completed; CI cannot merge a green PR |
| **S3** | Wrong behaviour, with a workaround | An issue must be closed by hand |
| **S4** | Cosmetic | A name clips at the largest font size |

Anything found and not fixed on the spot becomes an issue with steps to
reproduce, before the day ends. A defect that exists only in someone's memory
is a defect that ships.

**Every defect gets a failing test first**, then the fix. Otherwise there is no
evidence the fix worked and nothing stopping it coming back.

## Worked example: one criterion, traced

From `REQUIREMENTS.md`, R1.4:

> **Given** a turn was skipped, **when** the cycle comes around again, **then**
> the skipped member is not owed a double turn — a skip is forgiveness, not
> debt.

Becomes, in `test/domain/rota_engine_test.dart`:

```dart
test('the skipped member is not owed a double turn later', () {
  final RotaEngine engine = engineOf(
    skips: <SkippedTurn>[
      SkippedTurn(id: 's1', weekStart: start, memberId: jabulile.id),
    ],
  );
  final List<String> twoCycles = leadersFor(engine, 8);
  for (final String name in <String>['Jabulile', 'Sisi', 'Mama', 'Tata']) {
    expect(twoCycles.where((String n) => n == name).length, 2,
        reason: '$name should lead twice in eight weeks, got $twoCycles');
  }
});
```

Note what it asserts: not "week five is Sisi", which would pass even if the
rota had quietly shifted, but that **across two full cycles everyone leads
exactly twice** — which is what "not owed a double turn" actually means. The
`reason:` prints the real sequence, so a failure is diagnosable without a
debugger.

That is the standard: assert the claim the requirement makes, not the first
observable thing that correlates with it.
