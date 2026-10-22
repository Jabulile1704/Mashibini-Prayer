import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/skipped_turn.dart';

/// The Mashibini family as the documents describe them: four people, turnover
/// on Sunday, cycle anchored to Sunday 18 October 2026.
const Member jabulile = Member(id: 'm1', displayName: 'Jabulile');
const Member sisi = Member(id: 'm2', displayName: 'Sisi');
const Member mama = Member(id: 'm3', displayName: 'Mama');
const Member tata = Member(id: 'm4', displayName: 'Tata');

final CalendarDate anchor = CalendarDate(2026, 10, 18);

Family familyOfFour({List<SkippedTurn> skips = const <SkippedTurn>[]}) =>
    Family(
      id: 'f1',
      name: 'Mashibini',
      turnoverWeekday: DateTime.sunday,
      members: const <Member>[jabulile, sisi, mama, tata],
      cycles: <Cycle>[
        Cycle(
          id: 'c1',
          effectiveFrom: anchor,
          order: const <String>['m1', 'm2', 'm3', 'm4'],
        ),
      ],
      skips: skips,
    );
