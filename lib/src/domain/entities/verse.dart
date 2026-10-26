/// A verse, and where it came from.
///
/// [reference] is carried with the text rather than derived, because a verse
/// without its reference is a quotation nobody can check.
class Verse {
  const Verse({required this.reference, required this.text});

  final String reference;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is Verse && other.reference == reference && other.text == text;

  @override
  int get hashCode => Object.hash(reference, text);

  @override
  String toString() => 'Verse($reference)';
}

/// Which translation the verses are, and on what terms.
///
/// R3.2 requires the translation to be named wherever a verse is shown, and
/// requires that only a translation whose licence permits redistribution is
/// bundled. Carrying the licence in the data rather than in a comment means
/// the app can display it, and means swapping translations later changes a
/// file rather than a screen.
class Translation {
  const Translation({
    required this.name,
    required this.abbreviation,
    required this.licence,
    required this.notice,
  });

  final String name;
  final String abbreviation;
  final String licence;

  /// The wording shown in the app's about text, taken from the publisher.
  final String notice;
}
