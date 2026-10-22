import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/serialization/json_reads.dart';

/// These helpers exist to make a bad field say *which* field it was. A test
/// that only checks they throw would miss the entire point, so each one
/// asserts the message names the key and shows the value.
void main() {
  Matcher namesKeyAndValue(String key, String value) => throwsA(
    isA<FormatException>().having(
      (FormatException e) => e.message,
      'message',
      allOf(contains(key), contains(value)),
    ),
  );

  group('readString', () {
    test('reads a string', () {
      expect(readString(<String, Object?>{'a': 'x'}, 'a'), 'x');
    });

    test('names the field and shows the value when wrong', () {
      expect(
        () => readString(<String, Object?>{'a': 7}, 'a'),
        namesKeyAndValue('a', '7'),
      );
    });

    test('a missing field is as bad as a wrong one', () {
      expect(
        () => readString(<String, Object?>{}, 'name'),
        namesKeyAndValue('name', 'null'),
      );
    });
  });

  group('readStringOrNull', () {
    test('accepts a string, and null', () {
      expect(readStringOrNull(<String, Object?>{'a': 'x'}, 'a'), 'x');
      expect(readStringOrNull(<String, Object?>{'a': null}, 'a'), isNull);
      expect(readStringOrNull(<String, Object?>{}, 'a'), isNull);
    });

    test('refuses anything else', () {
      expect(
        () => readStringOrNull(<String, Object?>{'a': 7}, 'a'),
        namesKeyAndValue('a', '7'),
      );
    });
  });

  group('readInt and readIntOr', () {
    test('reads an integer', () {
      expect(readInt(<String, Object?>{'n': 3}, 'n'), 3);
    });

    test('refuses a numeric string — JSON types are not coerced', () {
      expect(
        () => readInt(<String, Object?>{'n': '3'}, 'n'),
        namesKeyAndValue('n', '3'),
      );
    });

    test('readIntOr falls back only when the key is absent', () {
      expect(readIntOr(<String, Object?>{}, 'n', 9), 9);
      expect(readIntOr(<String, Object?>{'n': 3}, 'n', 9), 3);
      expect(
        () => readIntOr(<String, Object?>{'n': 'x'}, 'n', 9),
        namesKeyAndValue('n', 'x'),
      );
    });
  });

  group('readStringList', () {
    test('reads a list of strings', () {
      expect(
        readStringList(<String, Object?>{
          'order': <Object?>['a', 'b'],
        }, 'order'),
        <String>['a', 'b'],
      );
    });

    test('refuses a list with a non-string in it', () {
      expect(
        () => readStringList(<String, Object?>{
          'order': <Object?>['a', 2],
        }, 'order'),
        namesKeyAndValue('order', '2'),
      );
    });

    test('refuses something that is not a list', () {
      expect(
        () => readStringList(<String, Object?>{'order': 'a,b'}, 'order'),
        namesKeyAndValue('order', 'a,b'),
      );
    });
  });

  group('readObjectList', () {
    Map<String, Object?> identity(Map<String, Object?> json) => json;

    test('reads a list of objects', () {
      final List<Map<String, Object?>> parsed = readObjectList(
        <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'id': '1'},
          ],
        },
        'items',
        identity,
      );
      expect(parsed, hasLength(1));
      expect(parsed.single['id'], '1');
    });

    test('an absent key is an empty list, not an error', () {
      expect(readObjectList(<String, Object?>{}, 'items', identity), isEmpty);
    });

    test('refuses a list with a non-object in it', () {
      expect(
        () => readObjectList(
          <String, Object?>{
            'items': <Object?>['nope'],
          },
          'items',
          identity,
        ),
        namesKeyAndValue('items', 'nope'),
      );
    });

    test('refuses something that is not a list', () {
      expect(
        () => readObjectList(<String, Object?>{'items': 5}, 'items', identity),
        namesKeyAndValue('items', '5'),
      );
    });
  });

  group('readObject', () {
    test('reads a nested object', () {
      expect(
        readObject(<String, Object?>{
          'inner': <String, Object?>{'a': 1},
        }, 'inner'),
        <String, Object?>{'a': 1},
      );
    });

    test('refuses a non-object', () {
      expect(
        () => readObject(<String, Object?>{'inner': 'x'}, 'inner'),
        namesKeyAndValue('inner', 'x'),
      );
    });
  });
}
