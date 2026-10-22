import 'dart:convert';

import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/cycle.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/skipped_turn.dart';
import 'json_reads.dart';

/// Translates between a [Family] and the JSON the local store holds.
///
/// Lives in the data layer rather than on the entities, so the storage format
/// can change — a Firestore document shape, a migration, a different store
/// entirely — without the domain knowing. The domain's job is the rota; it
/// should not also be a file format.
///
/// Every date is written as `yyyy-mm-dd`, the form `DATA-MODEL.md` specifies,
/// so what is on disk is legible to a person reading it.
abstract final class FamilyJson {
  static String encode(Family family) => jsonEncode(toMap(family));

  /// Parses [source], throwing [FormatException] if it is not a family.
  ///
  /// Throwing rather than returning null is deliberate here: an unreadable
  /// store is a defect to surface, not an empty state to render. The caller
  /// decides what to do about it — see `LocalFamilyRepository`.
  static Family decode(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('Expected a JSON object', source);
    }
    return fromMap(decoded);
  }

  static Map<String, Object?> toMap(Family family) => <String, Object?>{
    'schemaVersion': family.schemaVersion,
    'id': family.id,
    'name': family.name,
    'turnoverWeekday': family.turnoverWeekday,
    'members': <Map<String, Object?>>[
      for (final Member member in family.members) _memberToMap(member),
    ],
    'cycles': <Map<String, Object?>>[
      for (final Cycle cycle in family.cycles) _cycleToMap(cycle),
    ],
    'skips': <Map<String, Object?>>[
      for (final SkippedTurn skip in family.skips) _skipToMap(skip),
    ],
  };

  static Family fromMap(Map<String, Object?> json) {
    final int schemaVersion = readIntOr(
      json,
      'schemaVersion',
      Family.currentSchemaVersion,
    );
    if (schemaVersion > Family.currentSchemaVersion) {
      throw FormatException(
        'This family was written by a newer version of the app '
        '(schema $schemaVersion, this build reads '
        '${Family.currentSchemaVersion}). Refusing to read it rather than '
        'silently dropping fields.',
      );
    }
    return Family(
      id: readString(json, 'id'),
      name: readString(json, 'name'),
      turnoverWeekday: readInt(json, 'turnoverWeekday'),
      members: readObjectList(json, 'members', _memberFromMap),
      cycles: readObjectList(json, 'cycles', _cycleFromMap),
      skips: readObjectList(json, 'skips', _skipFromMap),
      schemaVersion: schemaVersion,
    );
  }

  static Map<String, Object?> _memberToMap(Member member) => <String, Object?>{
    'id': member.id,
    'displayName': member.displayName,
  };

  static Member _memberFromMap(Map<String, Object?> json) => Member(
    id: readString(json, 'id'),
    displayName: readString(json, 'displayName'),
  );

  static Map<String, Object?> _cycleToMap(Cycle cycle) => <String, Object?>{
    'id': cycle.id,
    'effectiveFrom': cycle.effectiveFrom.toString(),
    'order': cycle.order,
    'reason': cycle.reason.name,
  };

  static Cycle _cycleFromMap(Map<String, Object?> json) => Cycle(
    id: readString(json, 'id'),
    effectiveFrom: CalendarDate.parse(readString(json, 'effectiveFrom')),
    order: readStringList(json, 'order'),
    reason: _reasonFromName(readStringOrNull(json, 'reason')),
  );

  /// An unknown reason is not worth failing a load over.
  ///
  /// It is a label on a past decision, not something the rota computes with,
  /// so a newer build's value degrades to [CycleReason.reordered] rather than
  /// making the whole family unreadable.
  static CycleReason _reasonFromName(String? name) {
    for (final CycleReason reason in CycleReason.values) {
      if (reason.name == name) {
        return reason;
      }
    }
    return CycleReason.reordered;
  }

  static Map<String, Object?> _skipToMap(SkippedTurn skip) => <String, Object?>{
    'id': skip.id,
    'weekStart': skip.weekStart.toString(),
    'memberId': skip.memberId,
    if (skip.note != null) 'note': skip.note,
  };

  static SkippedTurn _skipFromMap(Map<String, Object?> json) => SkippedTurn(
    id: readString(json, 'id'),
    weekStart: CalendarDate.parse(readString(json, 'weekStart')),
    memberId: readString(json, 'memberId'),
    note: readStringOrNull(json, 'note'),
  );
}
