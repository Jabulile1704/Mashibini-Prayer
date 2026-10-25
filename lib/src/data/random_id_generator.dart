import 'dart:math';

import '../domain/ids.dart';

/// Ids unique enough that two phones offline will not collide.
///
/// Eleven random characters from a 32-character alphabet is 55 bits. A family
/// creating an id every day for a century would have a collision chance far
/// below the odds of the phone itself failing — which is the standard that
/// matters here, not cryptographic uniqueness.
///
/// Lives in the data layer because `dart:math` is not `dart:core`, and the
/// architecture's one hard rule is that the domain imports nothing else.
class RandomIdGenerator implements IdGenerator {
  RandomIdGenerator({Random? random}) : _random = random ?? Random.secure();

  /// No vowels and no look-alikes: an id that ends up read aloud down a
  /// phone line, or copied out of a database by hand, should not turn `0`
  /// into `O` or spell anything.
  static const String _alphabet = '23456789bcdfghjkmnpqrstvwxyz';

  static const int _length = 11;

  final Random _random;

  @override
  String newId(String prefix) {
    final StringBuffer id = StringBuffer(prefix);
    for (int i = 0; i < _length; i++) {
      id.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return id.toString();
  }
}
