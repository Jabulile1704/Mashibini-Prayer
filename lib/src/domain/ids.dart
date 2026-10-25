/// Makes ids for new members, cycles and skips.
///
/// This is an interface rather than a function because of R6.2. Ids used to
/// be counted from what was already there — the fifth member was `m5`, the
/// second cycle `c2` — which is fine on one phone and wrong on two: both
/// would mint `m5` for different people, and a merge keyed by id would then
/// collapse two additions into one and silently lose somebody.
///
/// An id therefore has to be unique without the two devices talking to each
/// other. Randomness does that, and randomness has to be injected so the
/// domain stays free of anything it cannot be tested without.
abstract interface class IdGenerator {
  /// A new id beginning with [prefix], unique without coordination.
  String newId(String prefix);
}
