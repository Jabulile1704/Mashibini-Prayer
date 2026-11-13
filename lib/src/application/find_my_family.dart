import '../data/repositories/family_repository.dart';
import '../data/sources/platform/identity.dart';
import '../data/sources/remote/remote_membership.dart';
import '../domain/entities/family.dart';

/// Reunites a phone with the family its account belongs to (#75).
///
/// Two jobs, and they are the same journey in opposite directions:
///
/// - a phone that **has** a family writes down which one, so that a future
///   reinstall can find it;
/// - a phone that has **no** family asks what it wrote down, and attaches to
///   whatever comes back.
///
/// The second is what turns a reinstall from "set the rota up again" into
/// "sign in". Until #143 lands it is also the only way a second device ever
/// sees an existing family, and it only works for an account that was
/// already in it.
class FindMyFamily {
  const FindMyFamily({
    required this.families,
    required this.memberships,
    required this.identity,
    required this.attachTo,
    this.onTrouble,
  });

  final FamilyRepository families;
  final RemoteMembership memberships;
  final Identity identity;

  /// Starts listening to a family's document. Passed in rather than reached
  /// for, so this can be exercised without a repository that syncs.
  final Future<void> Function(String familyId) attachTo;

  final void Function(Object error, StackTrace stack)? onTrouble;

  /// Runs at startup and after signing in. Does nothing useful when nobody
  /// is signed in, which is the ordinary case on a phone that has never
  /// been online.
  Future<void> call() async {
    final SignedIn? who = identity.current;
    if (who == null) {
      return;
    }

    try {
      final Family? mine = await families.load();

      if (mine != null) {
        await memberships.remember(uid: who.uid, familyId: mine.id);
        return;
      }

      final String? familyId = await memberships.familyIdFor(who.uid);
      if (familyId == null) {
        return;
      }

      // Attaching is enough. The document arrives on the watch, and the
      // repository saves it because there is nothing here to merge it with.
      await attachTo(familyId);
    } on Object catch (error, stack) {
      // Not being able to reach Firestore is an ordinary morning. The phone
      // still has whatever it had.
      onTrouble?.call(error, stack);
    }
  }
}
