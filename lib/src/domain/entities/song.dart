import 'calendar_date.dart';

/// A song this family loves, and who said so (#110, R7.1).
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
  final String addedBy;

  final CalendarDate addedOn;

  /// Somewhere to hear it, if anybody added one.
  final String? link;

  /// Whether it has been taken out of the book.
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
