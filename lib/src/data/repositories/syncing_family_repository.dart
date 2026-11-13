import 'dart:async';

import '../../domain/entities/family.dart';
import '../../domain/rota/family_merge.dart';
import '../serialization/family_json.dart';
import '../sources/remote/remote_family_source.dart';
import 'family_repository.dart';

/// The family, kept on this phone and published to the family's own
/// document (#75, R6.2).
///
/// **Local first, always.** Every read is answered from the phone and every
/// write lands on the phone before anything is attempted over the network,
/// because S3 says the app works without a signal and R6.1 says the rota is
/// readable offline. A network failure is reported and swallowed; it never
/// reaches the caller as a failed save.
class SyncingFamilyRepository implements FamilyRepository {
  SyncingFamilyRepository({
    required this._local,
    required this._remoteFor,
    this.onTrouble,
  });

  final FamilyRepository _local;
  final RemoteFamilySource Function(String familyId) _remoteFor;

  /// Told about anything the network did wrong. Never thrown at the caller.
  final void Function(Object error, StackTrace stack)? onTrouble;

  RemoteFamilySource? _remote;
  String? _attachedTo;

  // Cancelled in `_detach`, which `attachTo`, `clear` and `dispose` all go
  // through. The lint only looks inside the function that creates it.
  // ignore: cancel_subscriptions
  StreamSubscription<Family?>? _incoming;
  bool _disposed = false;

  @override
  Future<Family?> load() async {
    final Family? stored = await _local.load();
    if (stored != null) {
      await attachTo(stored.id);
    }
    return stored;
  }

  @override
  Future<void> save(Family family) async {
    await _local.save(family);
    await attachTo(family.id);
    await _push(family);
  }

  @override
  Stream<Family?> watch() => _local.watch();

  @override
  Future<void> clear() async {
    await _local.clear();
    await _detach();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _detach();
    await _local.dispose();
  }

  /// Starts listening to [familyId]'s document.
  ///
  /// Public because the first family a reinstalled phone hears about comes
  /// from its membership record rather than from anything stored here.
  Future<void> attachTo(String familyId) async {
    if (_disposed || _attachedTo == familyId) {
      return;
    }
    await _detach();
    _attachedTo = familyId;

    final RemoteFamilySource remote = _remoteFor(familyId);
    _remote = remote;
    _incoming = remote.watch().listen(_arrived, onError: _trouble);
  }

  Future<void> _detach() async {
    final StreamSubscription<Family?>? incoming = _incoming;
    _incoming = null;
    _remote = null;
    _attachedTo = null;
    await incoming?.cancel();
  }

  /// Another phone — or this one, coming back — has published something.
  Future<void> _arrived(Family? theirs) async {
    if (_disposed || theirs == null) {
      return;
    }

    final Family? mine = await _local.load();

    if (mine == null) {
      // Nothing to reconcile with: this phone has the account and no rota.
      await _local.save(theirs);
      return;
    }

    if (mine.id != theirs.id) {
      // Two families cannot be merged into one, and guessing which the
      // person meant would quietly rewrite a rota. ADR-008 unions logs
      // within one family; it has nothing to say about two.
      _trouble(
        StateError(
          'The document at ${theirs.id} is not this phone\'s family '
          '(${mine.id}), so nothing was merged',
        ),
        StackTrace.current,
      );
      return;
    }

    final Family merged = FamilyMerge.merge(mine, theirs);
    final String settled = FamilyJson.encode(merged);

    if (settled != FamilyJson.encode(mine)) {
      await _local.save(merged);
    }
    if (settled != FamilyJson.encode(theirs)) {
      // We hold something they do not. Handing it back is what makes the
      // merge converge rather than alternate.
      await _push(merged);
    }
  }

  Future<void> _push(Family family) async {
    final RemoteFamilySource? remote = _remote;
    if (remote == null) {
      return;
    }
    try {
      await remote.push(family);
    } on Object catch (error, stack) {
      // A phone with no signal is the normal case, not a failure.
      _trouble(error, stack);
    }
  }

  void _trouble(Object error, StackTrace stack) =>
      onTrouble?.call(error, stack);
}
