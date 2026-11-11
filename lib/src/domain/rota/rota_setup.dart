import '../entities/calendar_date.dart';
import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../ids.dart';
import 'week.dart';

/// Turns the answers a person can actually give into the data the engine
/// needs.
abstract final class RotaSetup {
  /// Builds a family whose rota already says what the person just told us.
  static Family build({
    required String familyId,
    required String familyName,
    required List<Member> members,
    required int turnoverWeekday,
    required String currentLeaderId,
    required CalendarDate today,
    required IdGenerator ids,
  }) {
    Week.assertValidWeekday(turnoverWeekday);

    if (members.length < 2) {
      throw ArgumentError.value(
        members.length,
        'members',
        'a rota needs at least two people',
      );
    }

    final Set<String> seenIds = <String>{
      for (final Member member in members) member.id,
    };
    if (seenIds.length != members.length) {
      throw ArgumentError.value(
        members.map((Member m) => m.id).toList(),
        'members',
        'two members share an id',
      );
    }

    final int leaderIndex = members.indexWhere(
      (Member member) => member.id == currentLeaderId,
    );
    if (leaderIndex < 0) {
      throw ArgumentError.value(
        currentLeaderId,
        'currentLeaderId',
        'is not one of the members',
      );
    }

    final List<String> rotated = <String>[
      for (int i = 0; i < members.length; i++)
        members[(leaderIndex + i) % members.length].id,
    ];

    return Family(
      id: familyId,
      name: familyName,
      members: List<Member>.unmodifiable(members),
      cycles: <Cycle>[
        Cycle(
          id: ids.newId('c'),
          effectiveFrom: Week.startOf(today, turnoverWeekday),
          order: rotated,
        ),
      ],
    );
  }
}
