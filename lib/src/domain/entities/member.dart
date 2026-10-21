/// One person in the family rota.
///
/// Deliberately thin: a name and an identity. Everything the app knows about
/// a person is on this class, and the data model says why there is no email,
/// no phone number and no avatar.
class Member {
  const Member({required this.id, required this.displayName});

  final String id;

  /// What appears on screen. The family's own name for the person.
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is Member && other.id == id && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);

  @override
  String toString() => 'Member($id, $displayName)';
}
