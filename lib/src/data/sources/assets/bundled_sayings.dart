import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../domain/entities/saying.dart';
import '../../../domain/saying/saying_for_the_day.dart';
import '../../serialization/json_reads.dart';

/// Loads the sayings that ship with the app.
abstract final class BundledSayings {
  static const String assetPath = 'assets/sayings.json';

  /// Parsed once and held, because the file is 12 KB and the home screen
  /// rebuilds whenever the rota does.
  static SayingForTheDay? _cached;

  static Future<SayingForTheDay> load({AssetBundle? bundle}) async {
    final SayingForTheDay? already = _cached;
    if (already != null) {
      return already;
    }
    final String source = await (bundle ?? rootBundle).loadString(assetPath);
    final SayingForTheDay parsed = parse(source);
    _cached = parsed;
    return parsed;
  }

  /// Exposed for tests, which need a cold read rather than whatever the last
  /// test left behind.
  static void forgetCache() => _cached = null;

  static SayingForTheDay parse(String document) {
    final Object? decoded = jsonDecode(document);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('sayings.json should be a JSON object');
    }

    final Map<String, Object?> source = readObject(decoded, 'source');

    return SayingForTheDay(
      source: SayingSource(
        tradition: readString(source, 'tradition'),
        languages: readStringList(source, 'languages'),
        notice: readString(source, 'notice'),
        reviewed: readBoolOr(source, 'reviewed', false),
      ),
      sayings: readObjectList(
        decoded,
        'sayings',
        (Map<String, Object?> json) => Saying(
          text: readString(json, 'text'),
          original: readStringOrNull(json, 'original'),
          language: readString(json, 'language'),
        ),
      ),
    );
  }
}
