import 'dart:async';

import 'package:mashibini_prayer/src/data/sources/remote/remote_family_source.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';

/// A family document in memory, with a hand on the wire.
class FakeRemoteFamilySource implements RemoteFamilySource {
  FakeRemoteFamilySource({this.familyId = 'f1'});

  final String familyId;

  late final StreamController<Family?> _document =
      StreamController<Family?>.broadcast(onCancel: () => cancelled++);

  /// Every family this source was asked to publish, in order.
  final List<Family> pushed = <Family>[];

  Family? stored;

  /// When set, [push] throws it — a phone with no signal.
  Object? failOnPush;

  int watchers = 0;
  int cancelled = 0;

  @override
  Future<Family?> fetch() async => stored;

  @override
  Future<void> push(Family family) async {
    final Object? failure = failOnPush;
    if (failure != null) {
      throw failure;
    }
    pushed.add(family);
    stored = family;
  }

  @override
  Stream<Family?> watch() {
    watchers++;
    return _document.stream;
  }

  /// Another phone has written to the document.
  void arrive(Family? family) => _document.add(family);
}

/// Lets whatever the repository started in response to an arrival finish.
Future<void> settle() async {
  for (int i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
