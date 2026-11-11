/// Makes ids for new members, cycles and skips.
abstract interface class IdGenerator {
  /// A new id beginning with [prefix], unique without coordination.
  String newId(String prefix);
}
