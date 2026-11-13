import 'package:mashibini_prayer/src/data/sources/remote/remote_membership.dart';

/// Which family each account said it was in, in memory.
class FakeRemoteMembership implements RemoteMembership {
  FakeRemoteMembership([Map<String, String>? initial])
    : byUid = <String, String>{...?initial};

  final Map<String, String> byUid;

  final List<String> lookedUp = <String>[];

  /// When set, every call throws it.
  Object? failure;

  @override
  Future<String?> familyIdFor(String uid) async {
    _check();
    lookedUp.add(uid);
    return byUid[uid];
  }

  @override
  Future<void> remember({required String uid, required String familyId}) async {
    _check();
    byUid[uid] = familyId;
  }

  void _check() {
    final Object? failing = failure;
    if (failing != null) {
      throw failing;
    }
  }
}
