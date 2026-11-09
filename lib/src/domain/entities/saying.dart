/// A saying, and the language it comes from.
///
/// Was `Verse`, with a `reference` and a `Translation`, when the app showed
/// scripture. A proverb has neither: it is carried orally, it has no chapter
/// and no translator, and the honest attribution is **which people and which
/// language** it comes from (ADR-025, R3.2).
class Saying {
  const Saying({required this.text, required this.language, this.original});

  /// The English.
  final String text;

  /// The saying in its own language, where the app can carry it honestly.
  ///
  /// Null is an ordinary answer rather than a gap. A proverb whose original
  /// wording nobody here can vouch for is better shown in English with its
  /// language named than guessed at in a family's own tongue — a proverb
  /// misspelled in isiXhosa in an isiXhosa family's app is worse than no
  /// proverb.
  final String? original;

  /// "isiXhosa", "Sesotho" — the attribution, and the whole of it.
  final String language;

  @override
  bool operator ==(Object other) =>
      other is Saying &&
      other.text == text &&
      other.original == original &&
      other.language == language;

  @override
  int get hashCode => Object.hash(text, original, language);

  @override
  String toString() => 'Saying(${original ?? text}, $language)';
}

/// Where the sayings come from, and on what terms.
///
/// R3.2 used to require naming the **translation** and bundling only one
/// whose licence permitted redistribution. A traditional saying has no
/// translation to license: it belongs to nobody, which is a different
/// problem rather than no problem. What it requires instead is that the app
/// does not claim the words as its own and does not lift a particular
/// published phrasing — a collection's English wording is that collection's,
/// even when the saying is not.
class SayingSource {
  const SayingSource({
    required this.tradition,
    required this.languages,
    required this.notice,
    required this.reviewed,
  });

  /// "Southern African".
  final String tradition;

  final List<String> languages;

  /// Shown in the app's about text.
  final String notice;

  /// Whether a speaker of these languages has checked the wording.
  ///
  /// Carried in the data rather than assumed, because the person who wrote
  /// these is not one. It is **false** until somebody who speaks isiXhosa
  /// and Sesotho has read them, and `AboutScreen` says so while it is.
  final bool reviewed;
}
