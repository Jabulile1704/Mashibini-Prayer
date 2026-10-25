import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/random_id_generator.dart';
import 'package:mashibini_prayer/src/data/serialization/family_json.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';

/// Families created before ADR-008 have counted ids — `m1`, `c1`. Families
/// created after have random ones. A phone that was set up last week and
/// updated today holds the first kind and will start writing the second.
///
/// Nothing migrates them, on purpose: the engine only ever *compares* ids, it
/// never parses them, so the two styles mix freely. These tests are what make
/// that a checked claim rather than a confident one.
void main() {
  final CalendarDate anchor = CalendarDate(2026, 10, 18);

  /// Exactly what Day 6's setup screen would have written.
  Family legacyFamily() => Family(
    id: 'f1',
    name: 'Mashibini',
    turnoverWeekday: DateTime.sunday,
    members: const <Member>[
      Member(id: 'm1', displayName: 'Jabulile'),
      Member(id: 'm2', displayName: 'Sisi'),
    ],
    cycles: <Cycle>[
      Cycle(id: 'c1', effectiveFrom: anchor, order: const <String>['m2', 'm1']),
    ],
  );

  test('a family written by the old scheme still reads', () {
    final Family restored = FamilyJson.decode(
      FamilyJson.encode(legacyFamily()),
    );

    expect(
      RotaEngine.forFamily(restored).turnOn(anchor)!.leader.displayName,
      'Sisi',
    );
  });

  test('a random id can be added to a counted rota', () {
    final Family after = FamilyEditor.addMember(
      legacyFamily(),
      displayName: 'Mama',
      today: anchor,
      ids: RandomIdGenerator(),
    );

    final RotaEngine engine = RotaEngine.forFamily(after);
    // Mama joins at the end of a cycle that already had two people, so she
    // leads third: Sisi finishes the week in progress, then Jabulile and
    // Sisi take their turns under the new epoch, then Mama.
    expect(engine.turnOn(anchor)!.leader.displayName, 'Sisi');
    expect(engine.turnOn(anchor.addDays(7))!.leader.displayName, 'Jabulile');
    expect(engine.turnOn(anchor.addDays(14))!.leader.displayName, 'Sisi');
    expect(engine.turnOn(anchor.addDays(21))!.leader.displayName, 'Mama');
  });

  test('the mixed family survives a round trip through storage', () {
    final Family after = FamilyEditor.addMember(
      legacyFamily(),
      displayName: 'Mama',
      today: anchor,
      ids: RandomIdGenerator(),
    );

    final Family restored = FamilyJson.decode(FamilyJson.encode(after));

    expect(
      <String>[
        for (int w = 0; w < 4; w++)
          RotaEngine.forFamily(restored)
              .turnOn(anchor.addDays(w * 7))!
              .leader
              .displayName,
      ],
      <String>['Sisi', 'Jabulile', 'Sisi', 'Mama'],
    );
  });

  test('a counted id and a random one never collide by construction', () {
    final RandomIdGenerator ids = RandomIdGenerator();
    final Set<String> counted = <String>{'m1', 'm2', 'm3', 'c1', 'c2'};

    for (int i = 0; i < 1000; i++) {
      expect(counted.contains(ids.newId('m')), isFalse);
      expect(counted.contains(ids.newId('c')), isFalse);
    }
  });
}
