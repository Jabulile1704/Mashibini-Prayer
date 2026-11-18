import '../ids.dart';

/// The family's id, as somebody joining is asked to type it (#143).
abstract final class FamilyCode {
  static const String prefix = 'f';

  /// Reads a code a person typed, or null if no generator could have made
  /// it.
  ///
  /// Forgiving about how it arrives — spaces, dashes, capitals, a leading
  /// `#` somebody added for tidiness — and unforgiving about what it is.
  /// Every character of the alphabet is lower case and none of them look
  /// like each other, so folding case loses nothing (ADR-008).
  static String? parse(String typed) {
    final String cleaned = typed.toLowerCase().replaceAll(
      RegExp(r'[\s\-_#]'),
      '',
    );
    return IdScheme.looksLike(cleaned, prefix) ? cleaned : null;
  }
}

/// A Firebase account id, as the person it belongs to is asked to send it.
///
/// Not an id this app makes, so there is no scheme to check it against —
/// Firebase's are twenty-eight characters of mixed case, which is exactly
/// why ADR-027 says to move this as text rather than read it aloud. What
/// can be checked is that it is one token and a plausible length, which
/// catches a half-copied paste.
abstract final class AccountCode {
  static const int shortest = 20;
  static const int longest = 128;

  static String? parse(String typed) {
    final String cleaned = typed.trim();
    if (cleaned.length < shortest || cleaned.length > longest) {
      return null;
    }
    if (RegExp(r'[^A-Za-z0-9_\-]').hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }
}
