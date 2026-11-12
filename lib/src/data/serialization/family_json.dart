import 'dart:convert';

import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/cycle.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/skipped_turn.dart';
import '../../domain/entities/song.dart';
import 'json_reads.dart';

/// Translates between a [Family] and the JSON the local store holds.
abstract final class FamilyJson {
  static String encode(Family family) => jsonEncode(toMap(family));

  /// Parses [source], throwing [FormatException] if it is not a family.
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
    'memberUids': family.memberUids,
    'members': <Map<String, Object?>>[
      for (final Member member in family.members) _memberToMap(member),
    ],
    'cycles': <Map<String, Object?>>[
      for (final Cycle cycle in family.cycles) _cycleToMap(cycle),
    ],
    'skips': <Map<String, Object?>>[
      for (final SkippedTurn skip in family.skips) _skipToMap(skip),
    ],
    if (family.songs.isNotEmpty)
      'songs': <Map<String, Object?>>[
        for (final Song song in family.songs) _songToMap(song),
      ],
  };

  /// Reads a family, migrating it to the current schema on the way through.
  static Family fromMap(Map<String, Object?> json) {
    final int schemaVersion = readIntOr(json, 'schemaVersion', 1);
    if (schemaVersion > Family.currentSchemaVersion) {
      throw FormatException(
        'This family was written by a newer version of the app '
        '(schema $schemaVersion, this build reads '
        '${Family.currentSchemaVersion}). Refusing to read it rather than '
        'silently dropping fields.',
      );
    }

    final List<Cycle> cycles = readObjectList(json, 'cycles', _cycleFromMap);
    if (cycles.isEmpty) {
      throw const FormatException(
        'A family needs at least one cycle; this document has none',
      );
    }

    return Family(
      id: readString(json, 'id'),
      name: readString(json, 'name'),
      members: readObjectList(json, 'members', _memberFromMap),
      cycles: cycles,
      skips: readObjectList(json, 'skips', _skipFromMap),
      songs: json.containsKey('songs')
          ? readObjectList(json, 'songs', _songFromMap)
          : const <Song>[],
      schemaVersion: Family.currentSchemaVersion,
    );
  }

  /// Photographs that older documents stored on the member record, by
  /// member id (#140).
  ///
  /// Read defensively rather than through [fromMap], because the migration
  /// that calls this runs before anything has established that the stored
  /// document is a family at all.
  static Map<String, String> devicePhotosIn(Map<String, Object?> json) {
    final Object? members = json['members'];
    if (members is! List<Object?>) {
      return const <String, String>{};
    }
    return <String, String>{
      for (final Object? member in members)
        if (member is Map<String, Object?>)
          if (member['id'] case final String id)
            if (member['photoPath'] case final String path)
              if (path.isNotEmpty) id: path,
    };
  }

  static Map<String, Object?> _memberToMap(Member member) => <String, Object?>{
    'id': member.id,
    'displayName': member.displayName,
    if (member.uid != null) 'uid': member.uid,
    if (member.role != null) 'role': member.role,
    if (member.parentIds.isNotEmpty) 'parentIds': member.parentIds,
  };

  static Member _memberFromMap(Map<String, Object?> json) => Member(
    id: readString(json, 'id'),
    displayName: readString(json, 'displayName'),
    role: readStringOrNull(json, 'role'),
    uid: readStringOrNull(json, 'uid'),
    parentIds: json.containsKey('parentIds')
        ? readStringList(json, 'parentIds')
        : const <String>[],
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
  static CycleReason _reasonFromName(String? name) {
    for (final CycleReason reason in CycleReason.values) {
      if (reason.name == name) {
        return reason;
      }
    }
    return CycleReason.reordered;
  }

  static Map<String, Object?> _songToMap(Song song) => <String, Object?>{
    'id': song.id,
    'title': song.title,
    'addedBy': song.addedBy,
    'addedOn': song.addedOn.toString(),
    if (song.performer != null) 'performer': song.performer,
    if (song.link != null) 'link': song.link,
    if (song.removed) 'removed': true,
  };

  static Song _songFromMap(Map<String, Object?> json) => Song(
    id: readString(json, 'id'),
    title: readString(json, 'title'),
    addedBy: readString(json, 'addedBy'),
    addedOn: CalendarDate.parse(readString(json, 'addedOn')),
    performer: readStringOrNull(json, 'performer'),
    link: readStringOrNull(json, 'link'),
    removed: readBoolOr(json, 'removed', false),
  );

  static Map<String, Object?> _skipToMap(SkippedTurn skip) => <String, Object?>{
    'id': skip.id,
    'weekStart': skip.weekStart.toString(),
    'memberId': skip.memberId,
    if (skip.withdrawn) 'withdrawn': true,
    if (skip.note != null) 'note': skip.note,
  };

  static SkippedTurn _skipFromMap(Map<String, Object?> json) => SkippedTurn(
    id: readString(json, 'id'),
    weekStart: CalendarDate.parse(readString(json, 'weekStart')),
    memberId: readString(json, 'memberId'),
    withdrawn: readBoolOr(json, 'withdrawn', false),
    note: readStringOrNull(json, 'note'),
  );
}
