import 'dart:convert';
import 'dart:io';

import 'package:mashibini_prayer/src/data/serialization/family_json.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/skipped_turn.dart';
import 'package:mashibini_prayer/src/domain/entities/song.dart';

/// Writes the document the **app** produces, for the rules tests to use.
///
/// The rules in `firestore.rules` have asked for `memberUids` since Day 9
/// and passed every test since. The app wrote no such field, so the first
/// real sync would have been refused on every write — and nothing would
/// have caught it, because the rules tests hand-build the documents they
/// test against.
///
/// Both halves were correct in isolation and had never been introduced.
/// This is the introduction: one fixture, emitted by the app's own
/// serialiser, which the rules tests read instead of inventing their own.
///
/// Run by `.github/workflows/ci.yml` before the rules tests:
///
/// ```sh
/// dart run tool/emit_rules_fixture.dart
/// ```
///
/// It deliberately writes rather than asserts. A Dart test cannot reach the
/// Firestore emulator and the JavaScript tests cannot reach `FamilyJson`;
/// a file on disk is the only honest seam between them.
void main(List<String> arguments) {
  final CalendarDate anchor = CalendarDate(2026, 10, 18);

  // Two signed-in members and one who has not signed in, because that
  // mixture is what a real family looks like partway through adopting the
  // app — and it is the case where `memberUids` is a subset of `members`.
  //
  // Furnished rather than minimal: a skip, a song and a parent, because an
  // empty list proves nothing about the field that holds it. `songs`
  // arrived on Day 26 and the rules were written on Day 9; until this
  // fixture carried one, no test had ever offered the rules a document with
  // songs in it.
  final Family family = Family(
    id: 'f1',
    name: 'Mashibini',
    members: <Member>[
      const Member(
        id: 'm1',
        displayName: 'Jabulile',
        uid: 'uid-jabulile',
        role: 'eldest',
        parentIds: <String>['m3'],
      ),
      const Member(id: 'm2', displayName: 'Sisi', uid: 'uid-sisi'),
      const Member(id: 'm3', displayName: 'Mama'),
    ],
    cycles: <Cycle>[
      Cycle(
        id: 'c1',
        effectiveFrom: anchor,
        order: const <String>['m1', 'm2', 'm3'],
      ),
    ],
    skips: <SkippedTurn>[
      SkippedTurn(
        id: 's1',
        weekStart: anchor.addDays(7),
        memberId: 'm2',
        note: 'away that week',
      ),
    ],
    songs: <Song>[
      Song(
        id: 'song-1',
        title: 'Nkosi Sikelel iAfrika',
        addedBy: 'm1',
        addedOn: anchor,
      ),
    ],
  );

  final String path = arguments.isEmpty
      ? 'test/rules/fixtures/family-from-the-app.json'
      : arguments.first;

  final File out = File(path);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(FamilyJson.toMap(family)),
  );

  stdout.writeln('wrote $path');
  stdout.writeln('  memberUids: ${family.memberUids}');
  stdout.writeln('  schemaVersion: ${family.schemaVersion}');
  stdout.writeln('  keys: ${FamilyJson.toMap(family).keys.join(', ')}');
}
