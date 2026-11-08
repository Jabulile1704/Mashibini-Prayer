/// One person in the family.
///
/// Was deliberately thin — a name and an identity — on the grounds that the
/// app needed nothing else and N4 says collect only what is needed. The
/// family tree (#109) is what needed more, and each addition below is here
/// because a screen asks for it, not in case one might.
///
/// **Being in the family is not the same as being in the rota.** `Family.
/// members` holds everyone the app knows: people currently taking a week,
/// people who have stopped, and people who were never in the rota at all —
/// a grandchild belongs in the tree without being handed a week of prayer.
/// Who is *currently* in the rota is answered by the current cycle's order
/// and nothing else, so there is no second flag here to disagree with it.
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
  ///
  /// Free text and optional, because a family's words for its own people are
  /// not a list anybody else gets to write. No enum, no "relationship type":
  /// the app has no business knowing what the categories are.
  final String? role;

  /// A photograph on **this phone**, as an absolute path.
  ///
  /// Never uploaded. ADR-010 shuts the door on file uploads and that clause
  /// is untouched: the image is copied into the app's own directory and the
  /// path is stored. Which means it does not sync, and a reinstall takes it
  /// — the same bargain as the journal before #104, and said plainly on the
  /// screen rather than discovered.
  ///
  /// A path, not bytes. Putting an image in the family document would send
  /// it to Firestore the moment #75 lands, which is the upload this is
  /// avoiding.
  final String? photoPath;

  /// Whoever this person is a child of, within this family.
  ///
  /// Zero, one or two, and the tree is drawn from these. Ids rather than a
  /// nested structure so that the shape stays a set of edges: a family is
  /// not reliably a tree — remarriages, a grandparent raising a grandchild
  /// — and a nested type would force one where there is none.
  ///
  /// Nothing here touches the rota. A parent does not inherit a turn and a
  /// child is not owed one.
  final List<String> parentIds;

  /// Who this person is, to Firebase — null until they sign in (#76).
  ///
  /// The security rules written on Day 9 ask `request.auth.uid in
  /// resource.data.memberUids`, and until this field existed the app wrote
  /// no uids at all. The rules passed their own tests and would have
  /// refused every document the app produces; see `Family.memberUids`.
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
