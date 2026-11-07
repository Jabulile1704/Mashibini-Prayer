import 'dart:convert';

import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/cycle.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/skipped_turn.dart';
import '../../domain/entities/song.dart';
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
    // Written, never read back. It is derived from the cycles now (#100), so
    // reading it would be reading a copy of something already in the
    // document. It stays because `DATA-MODEL.md` presents the document as
    // legible to a person, and "which day does this family hand over on" is
    // a tedious thing to work out from a date.
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
    // Written only when there are any, so a family that has never added a
    // song carries no field describing its absence — and a v3 document and
    // a v4 one with an empty book are byte-identical.
    if (family.songs.isNotEmpty)
      'songs': <Map<String, Object?>>[
        for (final Song song in family.songs) _songToMap(song),
      ],
  };

  /// Reads a family, migrating it to the current schema on the way through.
  ///
  /// Three migrations so far and none of them moves a byte. v1 to v2 changed what
  /// the turnover day *meant*; v2 to v3 added three optional fields to a
  /// member, so a v2 document is a v3 family with no tree recorded — which
  /// is what it is. See [Family.currentSchemaVersion]. A v1 document's cycles are all anchored
  /// to the single `turnoverWeekday` it carries, which is exactly what each
  /// cycle's own [Cycle.turnoverWeekday] now reports, so a v1 family read by
  /// this build answers every date identically. The version is raised rather
  /// than kept because what is written next must carry the new marker: a
  /// family left stamped v1 would be read by an older build, which would
  /// then be free to crash on it the first time a turnover day moved.
  ///
  /// Migrating on read rather than on write is deliberate. A phone that
  /// opens the app and never changes anything is still upgraded, so there is
  /// no population of documents quietly stuck at an old version waiting to
  /// be found by the migration after next.
  static Family fromMap(Map<String, Object?> json) {
    // Absent means the oldest shape, not this one. A document written before
    // the field existed is v1 by definition, and defaulting to "current"
    // would wave every future migration past its own check.
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
    // A family's turnover day is now read off its cycles, so a document with
    // none of them has no rota to speak of rather than an empty one. Caught
    // here, as a FormatException like every other unreadable store, instead
    // of as a StateError from inside the domain.
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

  static Map<String, Object?> _memberToMap(Member member) => <String, Object?>{
    'id': member.id,
    'displayName': member.displayName,
    // Written only when set, so a family that has recorded no tree carries
    // no empty fields describing its absence — and a v2 document and a v3
    // one with nothing filled in are byte-identical.
    if (member.role != null) 'role': member.role,
    if (member.photoPath != null) 'photoPath': member.photoPath,
    if (member.parentIds.isNotEmpty) 'parentIds': member.parentIds,
  };

  static Member _memberFromMap(Map<String, Object?> json) => Member(
    id: readString(json, 'id'),
    displayName: readString(json, 'displayName'),
    role: readStringOrNull(json, 'role'),
    // A path on **this** phone. Another device's path means nothing here,
    // and #75 will have to drop it on the way in rather than show a broken
    // image for somebody else's file.
    photoPath: readStringOrNull(json, 'photoPath'),
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
    // Written only when true. A family that has never taken a skip back
    // should not carry a field about it on every record, and absent reads
    // as false — which is also what every document written before this
    // field existed means.
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
