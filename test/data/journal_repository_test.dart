import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/journal_entry.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';

void main() {
  late FakeKeyValueStore store;
  late LocalJournalRepository journal;

  final CalendarDate monday = CalendarDate(2026, 10, 26);
  final DateTime noon = DateTime.utc(2026, 10, 26, 12);

  setUp(() {
    store = FakeKeyValueStore();
    journal = LocalJournalRepository(store: store, ids: FakeIdGenerator());
  });

  tearDown(() async => journal.dispose());

  group('an empty journal', () {
    test('has nothing in it, which is not an error', () async {
      expect(await journal.all(), isEmpty);
      expect(await journal.forDate(monday), isNull);
    });
  });

  group('writing (R4.1)', () {
    test('what was written comes back', () async {
      await journal.write(date: monday, text: 'For Mama', now: noon);

      final JournalEntry? entry = await journal.forDate(monday);
      expect(entry, isNotNull);
      expect(entry!.text, 'For Mama');
      expect(entry.date, monday);
    });

    test('it survives a new repository over the same store', () async {
      await journal.write(date: monday, text: 'Kept', now: noon);

      final LocalJournalRepository reopened = LocalJournalRepository(
        store: store,
        ids: FakeIdGenerator(),
      );
      addTearDown(reopened.dispose);

      expect((await reopened.forDate(monday))!.text, 'Kept');
    });

    test(
      'writing the same day again replaces rather than duplicates',
      () async {
        await journal.write(date: monday, text: 'First', now: noon);
        await journal.write(
          date: monday,
          text: 'Second',
          now: noon.add(const Duration(hours: 1)),
        );

        final List<JournalEntry> all = await journal.all();
        expect(all, hasLength(1));
        expect(all.single.text, 'Second');
      },
    );

    test(
      'an edit keeps the entry id, so sync has something to match on',
      () async {
        await journal.write(date: monday, text: 'First', now: noon);
        final String id = (await journal.forDate(monday))!.id;

        await journal.write(
          date: monday,
          text: 'Edited',
          now: noon.add(const Duration(hours: 2)),
        );

        expect((await journal.forDate(monday))!.id, id);
      },
    );

    test('text is trimmed', () async {
      await journal.write(date: monday, text: '  spaced  ', now: noon);

      expect((await journal.forDate(monday))!.text, 'spaced');
    });

    test(
      'clearing the box deletes the entry rather than storing a blank',
      () async {
        await journal.write(date: monday, text: 'Something', now: noon);

        await journal.write(date: monday, text: '   ', now: noon);

        expect(await journal.forDate(monday), isNull);
        expect(await journal.all(), isEmpty);
      },
    );

    test('clearing a day that was never written does nothing', () async {
      await journal.write(date: monday, text: '', now: noon);

      expect(await journal.all(), isEmpty);
    });

    test('each day is its own entry', () async {
      await journal.write(date: monday, text: 'Monday', now: noon);
      await journal.write(date: monday.addDays(1), text: 'Tuesday', now: noon);

      expect(await journal.all(), hasLength(2));
    });
  });

  group('looking back (R4.3)', () {
    Future<void> writeDays(int count) async {
      for (int i = 0; i < count; i++) {
        await journal.write(
          date: monday.subtractDays(i),
          text: 'Entry $i',
          now: noon,
        );
      }
    }

    test('entries come back newest first', () async {
      await writeDays(5);

      final List<JournalEntry> all = await journal.all();
      for (int i = 1; i < all.length; i++) {
        expect(
          all[i - 1].date.isAfter(all[i].date),
          isTrue,
          reason: '${all[i - 1].date} should come before ${all[i].date}',
        );
      }
    });

    test('entries carry the month they belong to, for grouping', () async {
      await journal.write(
        date: CalendarDate(2026, 9, 30),
        text: 'September',
        now: noon,
      );
      await journal.write(
        date: CalendarDate(2026, 10, 1),
        text: 'October',
        now: noon,
      );

      final List<JournalEntry> all = await journal.all();
      expect(all.map((JournalEntry e) => e.month), <String>[
        '2026-10',
        '2026-09',
      ]);
    });

    test('a month number is padded, so months sort as strings', () async {
      await journal.write(
        date: CalendarDate(2026, 3, 1),
        text: 'March',
        now: noon,
      );

      expect((await journal.all()).single.month, '2026-03');
    });
  });

  group('deleting', () {
    test('removes the entry and forgets its id', () async {
      await journal.write(date: monday, text: 'Gone soon', now: noon);
      final String id = (await journal.forDate(monday))!.id;

      await journal.delete(id);

      expect(await journal.all(), isEmpty);
      expect(store.values.keys.where((String k) => k.contains(id)), isEmpty);
    });

    test('deleting something that is not there is harmless', () async {
      await expectLater(journal.delete('nothing'), completes);
    });
  });

  group('storage that has drifted', () {
    test('an index naming a missing entry skips it and tidies up', () async {
      await journal.write(date: monday, text: 'Real', now: noon);
      final String id = (await journal.forDate(monday))!.id;

      // As if a write half-failed: the index remembers, the entry is gone.
      store.values.remove('${LocalJournalRepository.entryPrefix}$id');

      expect(await journal.all(), isEmpty);
      expect(
        await journal.all(),
        isEmpty,
        reason: 'the index should have been tidied on the first read',
      );
    });

    test('one unreadable entry does not cost the whole journal', () async {
      await journal.write(date: monday, text: 'Good', now: noon);
      await journal.write(
        date: monday.subtractDays(1),
        text: 'Also good',
        now: noon,
      );
      final String id = (await journal.forDate(monday))!.id;
      store.values['${LocalJournalRepository.entryPrefix}$id'] = '{ broken';

      final List<JournalEntry> all = await journal.all();

      expect(all, hasLength(1));
      expect(all.single.text, 'Also good');
    });

    test('a corrupt index reads as empty rather than throwing', () async {
      store.values[LocalJournalRepository.indexKey] = 'not json';

      expect(await journal.all(), isEmpty);
    });

    test(
      'an index that is valid JSON but not a list is also survived',
      () async {
        // Different failure from unparseable: this one decodes cleanly into
        // the wrong shape, which a try/catch alone would not notice.
        store.values[LocalJournalRepository.indexKey] = '{"not":"a list"}';

        expect(await journal.all(), isEmpty);
      },
    );

    test('an index holding things that are not ids ignores them', () async {
      store.values[LocalJournalRepository.indexKey] = '[1, null, true]';

      expect(await journal.all(), isEmpty);
    });
  });

  group('watching', () {
    test('a listener gets what is there, then every change', () async {
      final List<int> counts = <int>[];
      final subscription = journal.watch().listen(
        (List<JournalEntry> entries) => counts.add(entries.length),
      );
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await journal.write(date: monday, text: 'One', now: noon);
      await pumpEventQueue();
      await journal.write(date: monday.addDays(1), text: 'Two', now: noon);
      await pumpEventQueue();

      expect(counts, <int>[0, 1, 2]);
    });
  });

  group('after dispose', () {
    test('using it is a programming error', () async {
      await journal.dispose();

      expect(
        () => journal.write(date: monday, text: 'x', now: noon),
        throwsStateError,
      );
      expect(() => journal.watch().first, throwsStateError);
    });

    test('disposing twice is harmless', () async {
      await journal.dispose();
      await expectLater(journal.dispose(), completes);
    });
  });
}
