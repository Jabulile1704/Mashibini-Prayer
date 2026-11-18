import '../data/repositories/device_settings_repository.dart';
import '../data/repositories/family_repository.dart';
import '../data/sources/platform/identity.dart';
import '../data/sources/remote/remote_family_source.dart';
import '../data/sources/remote/remote_membership.dart';
import '../domain/entities/family.dart';
import '../domain/family/codes.dart';

/// What happened when this phone tried to join a family (#143).
sealed class JoinResult {
  const JoinResult();
}

/// Nobody is signed in, so there is no account to be admitted.
class NotSignedIn extends JoinResult {
  const NotSignedIn();
}

/// No generator could have produced that code, so it was not asked about.
class NotAFamilyCode extends JoinResult {
  const NotAFamilyCode();
}

/// There is no family with that id, or this account is not in it yet.
///
/// Deliberately one answer rather than two (ADR-027): if they could be told
/// apart, a family id would be worth something to somebody guessing.
class NotYourFamilyYet extends JoinResult {
  const NotYourFamilyYet();
}

/// This phone already has a rota, and joining would put it aside.
///
/// Two families cannot be merged — ADR-008 unions logs within one family and
/// has nothing to say about two — so this is a question, not a failure.
class WouldReplaceThisRota extends JoinResult {
  const WouldReplaceThisRota(this.mine);

  final Family mine;
}

/// The network did not answer. Nothing changed.
class CouldNotAsk extends JoinResult {
  const CouldNotAsk(this.error);

  final Object error;
}

/// Joined. The rota on this phone is the family's.
class Joined extends JoinResult {
  const Joined(this.family);

  final Family family;
}

/// Puts this phone into a family somebody has already admitted it to.
///
/// The admitting happens elsewhere and first — `FamilyEditor.linkUid` on a
/// phone that is already in the family. By the time this runs, the only
/// question left is whether the document will let us read it, and the answer
/// is the whole of the authorisation.
class JoinAFamily {
  const JoinAFamily({
    required this.families,
    required this.settings,
    required this.memberships,
    required this.identity,
    required this.remoteFor,
  });

  final FamilyRepository families;
  final DeviceSettingsRepository settings;
  final RemoteMembership memberships;
  final Identity identity;
  final RemoteFamilySource Function(String familyId) remoteFor;

  /// Joins the family [typed] names.
  ///
  /// Call again with [replacing] set once the person has been told what they
  /// are giving up.
  Future<JoinResult> call(String typed, {bool replacing = false}) async {
    final SignedIn? who = identity.current;
    if (who == null) {
      return const NotSignedIn();
    }

    final String? familyId = FamilyCode.parse(typed);
    if (familyId == null) {
      return const NotAFamilyCode();
    }

    final Family? mine = await families.load();
    final bool alreadyThisOne = mine != null && mine.id == familyId;
    if (mine != null && !alreadyThisOne && !replacing) {
      return WouldReplaceThisRota(mine);
    }

    final Family? theirs;
    try {
      theirs = await remoteFor(familyId).fetch();
    } on RemoteRefused {
      return const NotYourFamilyYet();
    } on Object catch (error) {
      return CouldNotAsk(error);
    }

    if (theirs == null) {
      return const NotYourFamilyYet();
    }

    if (!alreadyThisOne) {
      // Whoever this phone thought its owner was belonged to the other
      // rota, and that member id means nothing in this family. Asking again
      // beats showing somebody else's weeks as theirs.
      await settings.saveYouAre(null);
    }

    // Local first, as everywhere else. `save` is what attaches the
    // repository to the document, so there is nothing further to start.
    await families.save(theirs);
    await memberships.remember(uid: who.uid, familyId: familyId);

    return Joined(theirs);
  }
}
