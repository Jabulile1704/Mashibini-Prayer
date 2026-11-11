/// Typed reads out of decoded JSON.
library;

Never _bad(String key, Object? value, String expected) =>
    throw FormatException('Field "$key" should be $expected, got: $value');

String readString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  _bad(key, value, 'a string');
}

String? readStringOrNull(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null || value is String) {
    return value as String?;
  }
  _bad(key, value, 'a string or null');
}

int readInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  _bad(key, value, 'an integer');
}

int readIntOr(Map<String, Object?> json, String key, int fallback) {
  final Object? value = json[key];
  if (value == null) {
    return fallback;
  }
  if (value is int) {
    return value;
  }
  _bad(key, value, 'an integer or absent');
}

bool readBoolOr(Map<String, Object?> json, String key, bool fallback) {
  final Object? value = json[key];
  if (value == null) {
    return fallback;
  }
  if (value is bool) {
    return value;
  }
  _bad(key, value, 'a boolean or absent');
}

List<String> readStringList(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is List<Object?>) {
    return <String>[
      for (final Object? item in value)
        if (item is String) item else _bad(key, item, 'a list of strings'),
    ];
  }
  _bad(key, value, 'a list of strings');
}

/// Reads a list of objects, each parsed by [parse].
List<T> readObjectList<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?>) parse,
) {
  final Object? value = json[key];
  if (value == null) {
    return <T>[];
  }
  if (value is List<Object?>) {
    return <T>[
      for (final Object? item in value)
        if (item is Map<String, Object?>)
          parse(item)
        else
          _bad(key, item, 'a list of objects'),
    ];
  }
  _bad(key, value, 'a list of objects');
}

Map<String, Object?> readObject(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  _bad(key, value, 'an object');
}
