/// A saying, and the language it comes from.
class Saying {
  const Saying({required this.text, required this.language, this.original});

  /// The English.
  final String text;

  /// The saying in its own language, where the app can carry it honestly.
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
  final bool reviewed;
}
