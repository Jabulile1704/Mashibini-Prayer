import 'dart:math';

import '../domain/ids.dart';

/// Ids unique enough that two phones offline will not collide.
class RandomIdGenerator implements IdGenerator {
  RandomIdGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String newId(String prefix) {
    final StringBuffer id = StringBuffer(prefix);
    for (int i = 0; i < IdScheme.length; i++) {
      id.write(IdScheme.alphabet[_random.nextInt(IdScheme.alphabet.length)]);
    }
    return id.toString();
  }
}
