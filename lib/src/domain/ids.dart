/// Makes ids for new members, cycles and skips.
abstract interface class IdGenerator {
  /// A new id beginning with [prefix], unique without coordination.
  String newId(String prefix);
}

/// The shape of an id this app makes (ADR-008, #148).
///
/// Here rather than in `RandomIdGenerator` because the family's id is read
/// aloud and typed back in by somebody joining (#143), so the alphabet is
/// part of the scheme rather than a detail of how ids are produced.
abstract final class IdScheme {
  /// No vowels and no look-alikes: an id that ends up read aloud down a
  /// phone line, or copied out of a database by hand, should not turn `0`
  /// into `O` or spell anything.
  static const String alphabet = '23456789bcdfghjkmnpqrstvwxyz';

  static const int length = 11;

  /// Whether [value] could be an id this app made with [prefix].
  ///
  /// It cannot say whether the id exists — nothing on this phone can. It
  /// only refuses what no generator could ever have produced, so a typo
  /// costs nothing and never becomes a network request.
  static bool looksLike(String value, String prefix) {
    if (value.length != prefix.length + length) {
      return false;
    }
    if (!value.startsWith(prefix)) {
      return false;
    }
    for (final String character in value.substring(prefix.length).split('')) {
      if (!alphabet.contains(character)) {
        return false;
      }
    }
    return true;
  }
}
