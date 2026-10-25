import '../entities/calendar_date.dart';
import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../ids.dart';
import 'week.dart';

/// Turns the answers a person can actually give into the data the engine
/// needs.
///
/// Nobody should have to understand what an anchor date is to set up a rota
/// (R2.2). The three answerable questions are:
///
/// - who takes a week, and in what order
/// - which day the week turns over
/// - whose week it is *right now*
///
/// From those, the anchor falls out. This is the only place that derivation
/// happens, and it is pure, so it is tested without a screen.
abstract final class RotaSetup {
  /// Builds a family whose rota already says what the person just told us.
  ///
  /// The order is **rotated** so that the current leader sits first and the
  /// cycle's anchor is this week. The alternative — keeping the typed order
  /// and pushing the anchor back into the past — would make `startedOn` claim
  /// the rota began before the family had ever opened the app.
  ///
  /// Rotating costs nothing: a cycle has no first member, only an order, and
  /// the sequence after the current leader is unchanged.
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
      turnoverWeekday: turnoverWeekday,
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
