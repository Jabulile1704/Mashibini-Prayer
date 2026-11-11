import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/serialization/family_json.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/skipped_turn.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';

import '../support/family_fixtures.dart';

void main() {
  group('round trip', () {
    test('a family survives encode and decode unchanged', () {
      final Family original = familyOfFour(
        skips: <SkippedTurn>[
          SkippedTurn(
            id: 's1',
            weekStart: anchor,
            memberId: 'm1',
            note: 'away for a week',
          ),
        ],
      );

      final Family restored = FamilyJson.decode(FamilyJson.encode(original));

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.turnoverWeekday, original.turnoverWeekday);
      expect(restored.members, original.members);
      expect(restored.schemaVersion, original.schemaVersion);
      expect(restored.cycles.single.id, 'c1');
      expect(restored.cycles.single.effectiveFrom, anchor);
      expect(restored.cycles.single.order, <String>['m1', 'm2', 'm3', 'm4']);
      expect(restored.cycles.single.reason, CycleReason.initial);
      expect(restored.skips.single.memberId, 'm1');
      expect(restored.skips.single.weekStart, anchor);
      expect(restored.skips.single.note, 'away for a week');
      expect(restored.skips.single.withdrawn, isFalse);
    });

    test('a withdrawn skip is still withdrawn after a round trip', () {
      final Family original = familyOfFour(
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: anchor, memberId: 'm1').withdraw(),
        ],
      );

      final Family restored = FamilyJson.decode(FamilyJson.encode(original));

      expect(restored.skips.single.withdrawn, isTrue);
    });

    test('a skip written before the flag existed reads as a live skip', () {
      final String encoded = FamilyJson.encode(
        familyOfFour(
          skips: <SkippedTurn>[
            SkippedTurn(id: 's1', weekStart: anchor, memberId: 'm1'),
          ],
        ),
      );
      final Map<String, Object?> asMap =
          jsonDecode(encoded) as Map<String, Object?>;
      final List<Object?> skips = asMap['skips']! as List<Object?>;

      expect(
        (skips.single as Map<String, Object?>).containsKey('withdrawn'),
        isFalse,
        reason: 'a family that never withdrew a skip should not carry the key',
      );
      expect(FamilyJson.decode(encoded).skips.single.withdrawn, isFalse);
    });

    test('the restored family computes the same rota as the original', () {
      final Family original = familyOfFour();
      final Family restored = FamilyJson.decode(FamilyJson.encode(original));

      final RotaEngine before = RotaEngine.forFamily(original);
      final RotaEngine after = RotaEngine.forFamily(restored);

      for (int week = 0; week < 60; week++) {
        final CalendarDate date = anchor.addDays(week * 7);
        expect(
          after.turnOn(date)!.leader,
          before.turnOn(date)!.leader,
          reason: 'week $week ($date) differs after a round trip',
        );
      }
    });

    test('a family with no skips needs no skips key to read back', () {
      final Family restored = FamilyJson.fromMap(<String, Object?>{
        'id': 'f1',
        'name': 'Mashibini',
        'turnoverWeekday': 7,
        'members': <Object?>[
          <String, Object?>{'id': 'm1', 'displayName': 'Jabulile'},
        ],
        'cycles': <Object?>[
          <String, Object?>{
            'id': 'c1',
            'effectiveFrom': '2026-10-18',
            'order': <Object?>['m1'],
          },
        ],
      });
      expect(restored.skips, isEmpty);
    });
  });

  group('what is written', () {
    test('dates are written as yyyy-mm-dd, legible in the store', () {
      final String encoded = FamilyJson.encode(familyOfFour());
      expect(encoded, contains('"effectiveFrom":"2026-10-18"'));
      expect(encoded, isNot(contains('T00:00')));
    });

    test('an absent note is omitted rather than written as null', () {
      final String encoded = FamilyJson.encode(
        familyOfFour(
          skips: <SkippedTurn>[
            SkippedTurn(id: 's1', weekStart: anchor, memberId: 'm1'),
          ],
        ),
      );
      expect(encoded, isNot(contains('"note"')));
    });

    test('the schema version is written', () {
      expect(FamilyJson.encode(familyOfFour()), contains('"schemaVersion":4'));
    });

    test('the turnover day is written, for a person reading the file', () {
      expect(
        FamilyJson.encode(familyOfFour()),
        contains('"turnoverWeekday":7'),
      );
    });
  });

  group('bad data says which field is bad', () {
    Map<String, Object?> validMap() => FamilyJson.toMap(familyOfFour());

    test('a missing field names itself', () {
      final Map<String, Object?> json = validMap()..remove('name');
      expect(
        () => FamilyJson.fromMap(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('name'),
          ),
        ),
      );
    });

    test('a document with no cycles is not a family', () {
      final Map<String, Object?> json = validMap()..['cycles'] = <Object?>[];
      expect(
        () => FamilyJson.fromMap(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('at least one cycle'),
          ),
        ),
      );
    });

    test('a field of the wrong type names itself', () {
      final Map<String, Object?> json = validMap()..['name'] = 42;
      expect(
        () => FamilyJson.fromMap(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('name'), contains('42')),
          ),
        ),
      );
    });

    test('a date that is not a date is refused', () {
      final Map<String, Object?> json = validMap();
      (json['cycles']! as List<Object?>).clear();
      (json['cycles']! as List<Object?>).add(<String, Object?>{
        'id': 'c1',
        'effectiveFrom': 'last Sunday',
        'order': <Object?>['m1'],
      });
      expect(() => FamilyJson.fromMap(json), throwsFormatException);
    });

    test('decoding something that is not an object at all', () {
      expect(() => FamilyJson.decode('[]'), throwsFormatException);
      expect(() => FamilyJson.decode('"a string"'), throwsFormatException);
      expect(() => FamilyJson.decode('not json'), throwsFormatException);
    });
  });

  group('schema versions', () {
    test('refuses a family written by a newer build', () {
      final Map<String, Object?> json = FamilyJson.toMap(familyOfFour())
        ..['schemaVersion'] = Family.currentSchemaVersion + 1;
      expect(
        () => FamilyJson.fromMap(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('a document with no version at all is the oldest shape', () {
      final Map<String, Object?> json = FamilyJson.toMap(familyOfFour())
        ..remove('schemaVersion');
      expect(FamilyJson.fromMap(json).schemaVersion, 4);
      expect(
        RotaEngine.forFamily(FamilyJson.fromMap(json)).turnOn(anchor)!.leader,
        jabulile,
      );
    });

    test('an unknown cycle reason degrades rather than failing the load', () {
      final Map<String, Object?> json = FamilyJson.toMap(familyOfFour());
      final Map<String, Object?> cycle =
          (json['cycles']! as List<Object?>).first! as Map<String, Object?>;
      cycle['reason'] = 'somethingANewerBuildInvented';

      final Family restored = FamilyJson.fromMap(json);

      // The label is lost; the rota is not.
      expect(restored.cycles.single.reason, CycleReason.reordered);
      expect(restored.cycles.single.order, <String>['m1', 'm2', 'm3', 'm4']);
    });
  });

  group('reading a family written by v1.4.0', () {
    const String v1 = '''
{
  "schemaVersion": 1,
  "id": "f1",
  "name": "Mashibini",
  "turnoverWeekday": 7,
  "members": [
    {"id": "m1", "displayName": "Jabulile"},
    {"id": "m2", "displayName": "Sisi"},
    {"id": "m3", "displayName": "Mama"},
    {"id": "m4", "displayName": "Tata"}
  ],
  "cycles": [
    {
      "id": "c1",
      "effectiveFrom": "2026-10-18",
      "order": ["m1", "m2", "m3", "m4"],
      "reason": "initial"
    }
  ],
  "skips": [
    {"id": "s1", "weekStart": "2026-11-15", "memberId": "m2"}
  ]
}
''';

    test('it reads, and comes back stamped with the current version', () {
      final Family restored = FamilyJson.decode(v1);
      expect(restored.schemaVersion, 4);
      expect(restored.id, 'f1');
      expect(restored.members, hasLength(4));
      expect(restored.skips.single.id, 's1');
    });

    test('the turnover day it carried is the one it still reports', () {
      final Family restored = FamilyJson.decode(v1);
      expect(restored.turnoverWeekday, DateTime.sunday);
      expect(restored.cycles.single.turnoverWeekday, DateTime.sunday);
    });

    test('it answers every week of the next year identically', () {
      final RotaEngine migrated = RotaEngine.forFamily(FamilyJson.decode(v1));
      final RotaEngine native = RotaEngine.forFamily(
        familyOfFour(
          skips: <SkippedTurn>[
            SkippedTurn(
              id: 's1',
              weekStart: CalendarDate(2026, 11, 15),
              memberId: 'm2',
            ),
          ],
        ),
      );
      for (
        CalendarDate date = anchor;
        date.isBefore(CalendarDate(2027, 10, 18));
        date = date.addDays(1)
      ) {
        expect(
          migrated.turnOn(date),
          native.turnOn(date),
          reason: 'the migration changed the answer for $date',
        );
      }
    });

    test('and is written back as v4, so an older build refuses it', () {
      final String rewritten = FamilyJson.encode(FamilyJson.decode(v1));
      expect(rewritten, contains('"schemaVersion":4'));
    });

    test('a v1 document whose turnover day disagreed with its cycles now '
        'reads', () {
      final String inconsistent = v1.replaceFirst(
        '"turnoverWeekday": 7',
        '"turnoverWeekday": 1',
      );
      final Family restored = FamilyJson.decode(inconsistent);
      expect(restored.turnoverWeekday, DateTime.sunday);
      expect(RotaEngine.forFamily(restored).turnOn(anchor)!.leader, jabulile);
    });
  });

  group('Family', () {
    test('indexes its members by id', () {
      expect(familyOfFour().membersById['m3'], mama);
      expect(familyOfFour().membersById, hasLength(4));
    });

    test('copyWith keeps the id and schema version', () {
      final Family changed = familyOfFour().copyWith(name: 'Mashibini House');
      expect(changed.id, 'f1');
      expect(changed.name, 'Mashibini House');
      expect(changed.schemaVersion, Family.currentSchemaVersion);
      expect(changed.members, hasLength(4));
    });

    test('copyWith replaces only what it is given', () {
      final Family changed = familyOfFour().copyWith(
        members: const <Member>[jabulile],
      );
      expect(changed.members, const <Member>[jabulile]);
      expect(changed.turnoverWeekday, DateTime.sunday);
      expect(changed.name, 'Mashibini');
    });

    test('describes itself usefully', () {
      expect(
        familyOfFour().toString(),
        'Family(f1, Mashibini, 4 members, 1 cycles, 0 skips)',
      );
    });

    test('hands over on the day its latest epoch does', () {
      final Family family = Family(
        id: 'f1',
        name: 'Mashibini',
        members: const <Member>[jabulile, sisi],
        cycles: <Cycle>[
          Cycle(id: 'c1', effectiveFrom: anchor, order: const <String>['m1']),
          Cycle(
            id: 'c2',
            effectiveFrom: CalendarDate(2026, 11, 11), // a Wednesday
            order: const <String>['m2'],
          ),
        ],
      );
      expect(family.latestCycle.id, 'c2');
      expect(family.turnoverWeekday, DateTime.wednesday);
    });

    test('the latest epoch is found however the cycles are ordered', () {
      final List<Cycle> cycles = <Cycle>[
        Cycle(
          id: 'c2',
          effectiveFrom: CalendarDate(2026, 11, 11),
          order: const <String>['m2'],
        ),
        Cycle(id: 'c1', effectiveFrom: anchor, order: const <String>['m1']),
      ];
      final Family family = Family(
        id: 'f1',
        name: 'Mashibini',
        members: const <Member>[jabulile, sisi],
        cycles: cycles,
      );
      expect(family.latestCycle.id, 'c2');
    });

    test('two epochs on the same day are broken by id, as the engine does', () {
      final CalendarDate sameDay = CalendarDate(2026, 11, 15); // a Sunday
      final Family family = Family(
        id: 'f1',
        name: 'Mashibini',
        members: const <Member>[jabulile, sisi],
        cycles: <Cycle>[
          Cycle(id: 'c1', effectiveFrom: anchor, order: const <String>['m1']),
          Cycle(
            id: 'c-a1',
            effectiveFrom: sameDay,
            order: const <String>['m1'],
          ),
          Cycle(
            id: 'c-b1',
            effectiveFrom: sameDay,
            order: const <String>['m2'],
          ),
        ],
      );
      expect(family.latestCycle.id, 'c-b1');
      expect(
        RotaEngine.forFamily(family).cycleFor(sameDay).id,
        family.latestCycle.id,
      );
    });

    test('a family with no cycles has no turnover day to report', () {
      final Family family = Family(
        id: 'f1',
        name: 'Mashibini',
        members: const <Member>[jabulile],
        cycles: const <Cycle>[],
      );
      expect(() => family.turnoverWeekday, throwsStateError);
    });
  });
}
