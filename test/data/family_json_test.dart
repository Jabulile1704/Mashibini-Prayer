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
      // It has to be. The flag is the only thing standing between "we took
      // that skip back" and the rota quietly shifting again on next launch.
      final Family original = familyOfFour(
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: anchor, memberId: 'm1').withdraw(),
        ],
      );

      final Family restored = FamilyJson.decode(FamilyJson.encode(original));

      expect(restored.skips.single.withdrawn, isTrue);
    });

    test('a skip written before the flag existed reads as a live skip', () {
      // Forward compatibility the cheap way: absent means false, which is
      // what every document written before today means.
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
      expect(FamilyJson.encode(familyOfFour()), contains('"schemaVersion":1'));
    });
  });

  group('bad data says which field is bad', () {
    Map<String, Object?> validMap() => FamilyJson.toMap(familyOfFour());

    test('a missing field names itself', () {
      final Map<String, Object?> json = validMap()..remove('turnoverWeekday');
      expect(
        () => FamilyJson.fromMap(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('turnoverWeekday'),
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

    test('assumes the current version if none was written', () {
      final Map<String, Object?> json = FamilyJson.toMap(familyOfFour())
        ..remove('schemaVersion');
      expect(
        FamilyJson.fromMap(json).schemaVersion,
        Family.currentSchemaVersion,
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
  });
}
