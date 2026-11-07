import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/song.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';
import 'package:mashibini_prayer/src/domain/rota/family_merge.dart';

import '../support/fake_id_generator.dart';
import '../support/family_fixtures.dart';

/// The family songbook (#110).
///
/// Two things to keep straight, and the tests are mostly about them: a song
/// is **not a turn**, so nothing here touches the rota; and the book is
/// append-only, so removing is marking rather than deleting.
void main() {
  Family withSongs() {
    Family family = familyOfFour();
    family = FamilyEditor.addSong(
      family,
      title: 'Siyahamba',
      addedBy: mama.id,
      today: anchor,
      ids: FakeIdGenerator(),
    );
    return FamilyEditor.addSong(
      family,
      title: 'Thuma Mina',
      performer: 'Hugh Masekela',
      addedBy: jabulile.id,
      today: anchor.addDays(1),
      ids: DistinctIdGenerator('b'),
    );
  }

  group('adding a song', () {
    test('it is in the book straight away, with who chose it', () {
      final Family after = withSongs();
      final List<Song> book = FamilyEditor.songbook(after);

      expect(book, hasLength(2));
      expect(book.first.title, 'Thuma Mina');
      expect(book.first.performer, 'Hugh Masekela');
      expect(book.first.addedBy, jabulile.id);
      expect(book.last.addedBy, mama.id);
    });

    test('nothing about the rota changes', () {
      // A song is not a turn. If adding one wrote an epoch, everybody's
      // week would move because somebody wrote down what they like.
      final Family before = familyOfFour();
      final Family after = withSongs();

      expect(after.cycles, hasLength(before.cycles.length));
      expect(after.cycles.single.order, before.cycles.single.order);
      expect(after.members, before.members);
    });

    test('newest first, because a songbook is a record of adding', () {
      expect(
        FamilyEditor.songbook(withSongs()).map((Song s) => s.title),
        <String>['Thuma Mina', 'Siyahamba'],
      );
    });

    test('a title of only spaces is refused', () {
      expect(
        () => FamilyEditor.addSong(
          familyOfFour(),
          title: '   ',
          addedBy: mama.id,
          today: anchor,
          ids: FakeIdGenerator(),
        ),
        throwsArgumentError,
      );
    });

    test('somebody outside the family cannot have chosen it', () {
      expect(
        () => FamilyEditor.addSong(
          familyOfFour(),
          title: 'Siyahamba',
          addedBy: 'nobody',
          today: anchor,
          ids: FakeIdGenerator(),
        ),
        throwsArgumentError,
      );
    });

    test('an empty performer or link is absent rather than blank', () {
      final Family after = FamilyEditor.addSong(
        familyOfFour(),
        title: 'Siyahamba',
        performer: '  ',
        link: '',
        addedBy: mama.id,
        today: anchor,
        ids: FakeIdGenerator(),
      );
      expect(after.songs.single.performer, isNull);
      expect(after.songs.single.link, isNull);
    });
  });

  group('taking one out', () {
    test('it leaves the book but stays in the record', () {
      // Marked, not deleted. Two phones merge by union, so a deletion on
      // one would come back from the other (ADR-012).
      final Family after = withSongs();
      final String id = FamilyEditor.songbook(after).first.id;
      final Family removed = FamilyEditor.removeSong(after, songId: id);

      expect(FamilyEditor.songbook(removed), hasLength(1));
      expect(removed.songs, hasLength(2));
      expect(removed.songs.firstWhere((Song s) => s.id == id).removed, isTrue);
    });

    test('a song nobody has is refused rather than ignored', () {
      expect(
        () => FamilyEditor.removeSong(familyOfFour(), songId: 'nope'),
        throwsArgumentError,
      );
    });

    test('the same song can be added again afterwards', () {
      // `removed` never goes back to false, so adding again appends a new
      // record — which keeps the one-way rule without costing anybody the
      // ability to change their mind twice.
      Family family = withSongs();
      final String id = FamilyEditor.songbook(family).last.id;
      family = FamilyEditor.removeSong(family, songId: id);
      family = FamilyEditor.addSong(
        family,
        title: 'Siyahamba',
        addedBy: tata.id,
        today: anchor.addDays(5),
        ids: DistinctIdGenerator('c'),
      );

      expect(
        FamilyEditor.songbook(family).map((Song s) => s.title),
        contains('Siyahamba'),
      );
      expect(family.songs, hasLength(3));
    });
  });

  group('two phones', () {
    test('both sides keep what each added', () {
      final Family base = familyOfFour();
      final Family hers = FamilyEditor.addSong(
        base,
        title: 'Siyahamba',
        addedBy: mama.id,
        today: anchor,
        ids: DistinctIdGenerator('a'),
      );
      final Family his = FamilyEditor.addSong(
        base,
        title: 'Thuma Mina',
        addedBy: tata.id,
        today: anchor,
        ids: DistinctIdGenerator('b'),
      );

      final Family merged = FamilyMerge.merge(hers, his);
      expect(
        FamilyEditor.songbook(merged).map((Song s) => s.title).toSet(),
        <String>{'Siyahamba', 'Thuma Mina'},
      );
    });

    test('and the merge does not depend on which side goes first', () {
      final Family base = familyOfFour();
      final Family hers = FamilyEditor.addSong(
        base,
        title: 'Siyahamba',
        addedBy: mama.id,
        today: anchor,
        ids: DistinctIdGenerator('a'),
      );
      final Family his = FamilyEditor.addSong(
        base,
        title: 'Thuma Mina',
        addedBy: tata.id,
        today: anchor,
        ids: DistinctIdGenerator('b'),
      );

      expect(
        FamilyMerge.merge(hers, his).songs.map((Song s) => s.id).toList(),
        FamilyMerge.merge(his, hers).songs.map((Song s) => s.id).toList(),
      );
    });

    test('a removal survives meeting the copy that still has it', () {
      // The reason `removed` is a flag. A deletion would lose this race
      // every time.
      final Family both = withSongs();
      final String id = FamilyEditor.songbook(both).first.id;
      final Family removed = FamilyEditor.removeSong(both, songId: id);

      for (final Family merged in <Family>[
        FamilyMerge.merge(removed, both),
        FamilyMerge.merge(both, removed),
      ]) {
        expect(
          merged.songs.firstWhere((Song s) => s.id == id).removed,
          isTrue,
          reason: 'a song taken out must not come back from the other phone',
        );
      }
    });
  });
}
