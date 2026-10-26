import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../domain/entities/verse.dart';
import '../../../domain/verse/verse_for_the_day.dart';
import '../../serialization/json_reads.dart';

/// Loads the verses that ship with the app.
///
/// Bundled rather than fetched, for three reasons that all point the same
/// way: they are the same for everybody, they never change, and R3.1 says a
/// verse must be readable with no connection. An asset satisfies all three
/// and costs one file.
abstract final class BundledVerses {
  static const String assetPath = 'assets/verses.json';

  /// Parsed once and held, because the file is 12 KB and the home screen
  /// rebuilds whenever the rota does.
  static VerseForTheDay? _cached;

  static Future<VerseForTheDay> load({AssetBundle? bundle}) async {
    final VerseForTheDay? already = _cached;
    if (already != null) {
      return already;
    }
    final String source = await (bundle ?? rootBundle).loadString(assetPath);
    final VerseForTheDay parsed = parse(source);
    _cached = parsed;
    return parsed;
  }

  /// Exposed for tests, which need a cold read rather than whatever the last
  /// test left behind.
  static void forgetCache() => _cached = null;

  static VerseForTheDay parse(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('verses.json should be a JSON object');
    }

    final Map<String, Object?> translation = readObject(decoded, 'translation');

    return VerseForTheDay(
      translation: Translation(
        name: readString(translation, 'name'),
        abbreviation: readString(translation, 'abbreviation'),
        licence: readString(translation, 'licence'),
        notice: readString(translation, 'notice'),
      ),
      verses: readObjectList(
        decoded,
        'verses',
        (Map<String, Object?> json) => Verse(
          reference: readString(json, 'reference'),
          text: readString(json, 'text'),
        ),
      ),
    );
  }
}
