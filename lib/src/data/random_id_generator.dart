import 'dart:math';

import '../domain/ids.dart';

/// Ids unique enough that two phones offline will not collide.
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
