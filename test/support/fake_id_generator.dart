import 'package:mashibini_prayer/src/domain/ids.dart';

/// Predictable ids for tests: `m-1`, `m-2`, `c-1`, counted per prefix.
///
/// The separator is not decoration. Fixtures use `m1`..`m4`, and a generator
/// that counted from one would hand a "new" member the id of an existing one
/// — which is precisely the collision this whole change exists to prevent,
/// reproduced inside the tests meant to prove it cannot happen.
///
/// The real generator is random, which is the point of it — but a test that
/// asserts on an id needs to know what it will be, and a test that does not
/// should still read the same way twice.
///
/// [DistinctIdGenerator] exists for the one case where predictability is
/// exactly wrong: proving that two phones do not mint the same id.
class FakeIdGenerator implements IdGenerator {
  final Map<String, int> _counts = <String, int>{};

  @override
  String newId(String prefix) {
    final int next = (_counts[prefix] ?? 0) + 1;
    _counts[prefix] = next;
    return '$prefix-$next';
  }
}

/// Ids tagged with a device, so a collision between two "phones" would be
/// visible rather than accidental.
class DistinctIdGenerator implements IdGenerator {
  DistinctIdGenerator(this.device);

  final String device;
  final Map<String, int> _counts = <String, int>{};

  @override
  String newId(String prefix) {
    final int next = (_counts[prefix] ?? 0) + 1;
    _counts[prefix] = next;
    return '$prefix-$device$next';
  }
}
