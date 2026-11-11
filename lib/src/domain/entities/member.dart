/// One person in the family.
class Member {
  const Member({
    required this.id,
    required this.displayName,
    this.role,
    this.photoPath,
    this.parentIds = const <String>[],
    this.uid,
  });

  final String id;

  /// What appears on screen. The family's own name for the person.
  final String displayName;

  /// What they are to the family — "Mama", "eldest sister", "born 2019".
  final String? role;

  /// A photograph on **this phone**, as an absolute path.
  final String? photoPath;

  /// Whoever this person is a child of, within this family.
  final List<String> parentIds;

  /// Who this person is, to Firebase — null until they sign in (#76).
  final String? uid;

  Member copyWith({
    String? displayName,
    String? role,
    String? photoPath,
    List<String>? parentIds,
    String? uid,
    bool clearRole = false,
    bool clearPhoto = false,
  }) => Member(
    id: id,
    displayName: displayName ?? this.displayName,
    role: clearRole ? null : (role ?? this.role),
    photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    parentIds: parentIds ?? this.parentIds,
    uid: uid ?? this.uid,
  );

  @override
  bool operator ==(Object other) =>
      other is Member &&
      other.id == id &&
      other.displayName == displayName &&
      other.role == role &&
      other.photoPath == photoPath &&
      other.uid == uid &&
      _sameIds(other.parentIds, parentIds);

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    role,
    photoPath,
    uid,
    Object.hashAll(parentIds),
  );

  @override
  String toString() => 'Member($id, $displayName)';
}
