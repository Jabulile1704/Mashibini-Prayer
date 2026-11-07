import 'calendar_date.dart';

/// A song this family loves, and who said so (#110, R7.1).
///
/// The first thing in the app that is deliberately **shared**. The rota is
/// shared because it has to be; the journal is private by requirement
/// (R4.2). A songbook is neither — it is shared because that is the point of
/// it, and the screen has to make that obvious sitting one tab away from the
/// journal.
///
/// It is **text**, which is the whole reason it could be built now. A title,
/// who it is by, who chose it and a link is a few hundred bytes; fifty songs
/// are smaller than one photograph. So it rides the same append-only union
/// merge as the skips (ADR-008), costs nothing on the free tier, and touches
/// no clause of ADR-010 — there is no file here to upload.
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.addedBy,
    required this.addedOn,
    this.performer,
    this.link,
    this.removed = false,
  });

  final String id;

  /// What the family calls it. The only thing that is required.
  final String title;

  /// Who is singing it, if anybody said.
  final String? performer;

  /// The member who added it.
  ///
  /// Kept because "who chose this" is half of what a family songbook is
  /// for. A member id rather than a name, so a rename carries.
  final String addedBy;

  final CalendarDate addedOn;

  /// Somewhere to hear it, if anybody added one.
  ///
  /// Opened outside the app. Nothing here plays audio, and nothing here
  /// stores it — a link is a string, a recording is a file, and ADR-010 has
  /// something to say about the second one.
  final String? link;

  /// Whether it has been taken out of the book.
  ///
  /// Marked rather than deleted, for the same reason a skip is withdrawn
  /// rather than removed (ADR-012): two phones merge by union, so a record
  /// deleted on one would simply come back from the other. A flag merges in
  /// one direction and survives.
  ///
  /// It never goes back to false. Adding the same song again appends a new
  /// record with a new id, which keeps the one-way rule without costing
  /// anybody the ability to change their mind twice.
  final bool removed;

  Song remove() => Song(
    id: id,
    title: title,
    performer: performer,
    addedBy: addedBy,
    addedOn: addedOn,
    link: link,
    removed: true,
  );

  @override
  String toString() =>
      'Song($title${performer == null ? '' : ' — $performer'}'
      '${removed ? ', removed' : ''})';
}
