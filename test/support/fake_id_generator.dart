import 'package:mashibini_prayer/src/domain/ids.dart';

/// Predictable ids for tests: `m-1`, `m-2`, `c-1`, counted per prefix.
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
