import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/migrations/photo_paths_off_the_family.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/photo_library_repository.dart';
import 'package:mashibini_prayer/src/data/serialization/family_json.dart';

import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

/// Photographs belong to the phone, not to the family (#140).
void main() {
  late FakeKeyValueStore store;
  late PhotoLibraryRepository photos;

  setUp(() {
    store = FakeKeyValueStore();
    photos = PhotoLibraryRepository(store: store);
  });

  group('PhotoLibraryRepository', () {
    test('a phone with no photographs has none', () async {
      expect(await photos.all(), isEmpty);
      expect(await photos.pathFor('m1'), isNull);
    });

    test('remembers one per member', () async {
      await photos.remember('m1', '/tmp/one.jpg');
      await photos.remember('m2', '/tmp/two.jpg');

      expect(await photos.pathFor('m1'), '/tmp/one.jpg');
      expect(await photos.pathFor('m2'), '/tmp/two.jpg');
    });

    test('a second photograph replaces the first', () async {
      await photos.remember('m1', '/tmp/one.jpg');
      await photos.remember('m1', '/tmp/two.jpg');

      expect(await photos.all(), <String, String>{'m1': '/tmp/two.jpg'});
    });

    test('forgetting one leaves the others', () async {
      await photos.remember('m1', '/tmp/one.jpg');
      await photos.remember('m2', '/tmp/two.jpg');
      await photos.forget('m1');

      expect(await photos.all(), <String, String>{'m2': '/tmp/two.jpg'});
    });

    test('forgetting one that was never there is not an error', () async {
      await photos.forget('nobody');
      expect(await photos.all(), isEmpty);
    });

    test('rubbish in the store reads as no photographs', () async {
      await store.write(PhotoLibraryRepository.key, 'not json at all{');
      expect(() => photos.all(), throwsFormatException);

      await store.write(PhotoLibraryRepository.key, '["a list"]');
      expect(await photos.all(), isEmpty);
    });
  });

  group('PhotoPathsOffTheFamily', () {
    /// A document as builds before #140 wrote it.
    String oldDocument() {
      final Map<String, Object?> json = FamilyJson.toMap(familyOfFour());
      final List<Object?> members = json['members']! as List<Object?>;
      (members[2]! as Map<String, Object?>)['photoPath'] = '/tmp/mama.jpg';
      return FamilyJson.encode(FamilyJson.fromMap(json))
          .replaceFirst('"id":"m3"', '"id":"m3","photoPath":"/tmp/mama.jpg"');
    }

    test('keeps a photograph that was stored on the member', () async {
      await store.write(LocalFamilyRepository.storageKey, oldDocument());

      await PhotoPathsOffTheFamily.run(store: store, photos: photos);

      expect(await photos.pathFor('m3'), '/tmp/mama.jpg');
    });

    test('and takes it out of the document', () async {
      await store.write(LocalFamilyRepository.storageKey, oldDocument());

      await PhotoPathsOffTheFamily.run(store: store, photos: photos);

      final String after = store.values[LocalFamilyRepository.storageKey]!;
      expect(after, isNot(contains('photoPath')));
      expect(after, isNot(contains('/tmp/mama.jpg')));
    });

    test('runs once', () async {
      await store.write(LocalFamilyRepository.storageKey, oldDocument());
      await PhotoPathsOffTheFamily.run(store: store, photos: photos);

      // Somebody removes the photograph after the migration has run.
      await photos.forget('m3');
      await PhotoPathsOffTheFamily.run(store: store, photos: photos);

      expect(await photos.pathFor('m3'), isNull);
    });

    test('what this phone already knows wins', () async {
      await store.write(LocalFamilyRepository.storageKey, oldDocument());
      await photos.remember('m3', '/tmp/newer.jpg');

      await PhotoPathsOffTheFamily.run(store: store, photos: photos);

      expect(await photos.pathFor('m3'), '/tmp/newer.jpg');
    });

    test('a phone with no family yet is left alone', () async {
      await PhotoPathsOffTheFamily.run(store: store, photos: photos);
      expect(await photos.all(), isEmpty);
      expect(store.values[LocalFamilyRepository.storageKey], isNull);
    });

    test('a document that cannot be parsed does not stop the app', () async {
      await store.write(LocalFamilyRepository.storageKey, 'not json at all{');

      await expectLater(
        PhotoPathsOffTheFamily.run(store: store, photos: photos),
        completes,
      );
      expect(
        store.values[LocalFamilyRepository.storageKey],
        'not json at all{',
      );
    });

    test('a family with no cycles is left where it is', () async {
      await store.write(
        LocalFamilyRepository.storageKey,
        '{"id":"f1","name":"Mashibini","members":'
        '[{"id":"m3","displayName":"Mama","photoPath":"/tmp/mama.jpg"}],'
        '"cycles":[]}',
      );

      await PhotoPathsOffTheFamily.run(store: store, photos: photos);

      // The photograph is rescued even though the document cannot be read,
      // because the rescue does not need to understand the family.
      expect(await photos.pathFor('m3'), '/tmp/mama.jpg');
      expect(
        store.values[LocalFamilyRepository.storageKey],
        contains('photoPath'),
      );
    });
  });
}
