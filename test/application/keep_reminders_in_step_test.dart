import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/application/keep_reminders_in_step.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_reminders.dart';
import '../support/family_fixtures.dart';

/// Reminders follow the rota, not the screen that used to change it (#160).
void main() {
  late FakeKeyValueStore store;
  late LocalFamilyRepository families;
  late LocalDeviceSettingsRepository settings;
  late FakeReminders reminders;
  late KeepRemindersInStep subject;

  /// A Tuesday inside the anchor week, so there is always a next turn.
  final DateTime now = DateTime(2026, 10, 20, 9);

  setUp(() async {
    store = FakeKeyValueStore();
    families = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    reminders = FakeReminders();
    subject = KeepRemindersInStep(
      families: families,
      settings: settings,
      reminders: reminders,
      now: () => now,
    );
  });

  tearDown(() async {
    await subject.dispose();
    await families.dispose();
    await settings.dispose();
  });

  /// Lets the watcher's reaction finish.
  Future<void> settle() async {
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> switchedOn() async {
    await settings.saveRemindersEnabled(enabled: true);
    await settings.saveYouAre('m1');
  }

  group('a rota that changes while nobody is holding the phone', () {
    test('re-plans the reminders', () async {
      await switchedOn();
      await families.save(familyOfFour());
      subject.start();
      await settle();
      final int planned = reminders.scheduleCalls;

      // What `SyncingFamilyRepository` does when a merge arrives: it saves.
      // No screen is involved, which is the whole of #160.
      await families.save(
        FamilyEditor.skipTurn(
          familyOfFour(),
          weekStart: anchor.addDays(7),
          today: anchor,
          ids: FakeIdGenerator(),
        ),
      );
      await settle();

      expect(reminders.scheduleCalls, greaterThan(planned));
    });

    test('and the plan matches the rota that arrived', () async {
      await switchedOn();
      await families.save(familyOfFour());
      subject.start();
      await settle();

      await families.save(
        familyOfFour().copyWith(
          members: <Member>[
            jabulile,
            sisi,
            mama,
            tata,
            const Member(id: 'm5', displayName: 'Gogo'),
          ],
        ),
      );
      await settle();

      // Five in the cycle means the next turn for m1 is five weeks out, not
      // four. The figure is not the point; following the change is.
      expect(reminders.scheduled, isNotEmpty);
    });

    test('a phone that has left its family is not reminded about it', () async {
      await switchedOn();
      await families.save(familyOfFour());
      subject.start();
      await settle();
      expect(reminders.scheduleCalls, greaterThan(0));

      // `JoinAFamily` clears `youAre` and saves somebody else's rota.
      await settings.saveYouAre(null);
      await families.save(
        familyOfFour().copyWith(
          members: const <Member>[
            Member(id: 'x1', displayName: 'Somebody'),
            Member(id: 'x2', displayName: 'Else'),
          ],
        ),
      );
      await settle();

      expect(
        reminders.cancelCount,
        greaterThan(0),
        reason: 'a notification naming a week that belongs to nobody',
      );
    });
  });

  group('what it leaves alone', () {
    test('reminders nobody switched on', () async {
      await families.save(familyOfFour());
      subject.start();
      await settle();

      expect(reminders.scheduleCalls, 0);
      expect(reminders.cancelCount, 0);
    });

    test('a phone with no rota yet', () async {
      await switchedOn();
      subject.start();
      await settle();

      expect(reminders.scheduleCalls, 0);
    });
  });

  group('when the phone will not schedule', () {
    test('it is reported and swallowed', () async {
      await switchedOn();
      await families.save(familyOfFour());
      final List<Object> trouble = <Object>[];
      reminders.throwOnSchedule = StateError('notifications are off');

      KeepRemindersInStep(
        families: families,
        settings: settings,
        reminders: reminders,
        now: () => now,
        onTrouble: (Object error, StackTrace stack) => trouble.add(error),
      ).start();
      await settle();

      // Not a count: it follows two streams, so the number of re-plans is
      // not the contract. That nothing is thrown at the caller is.
      expect(trouble, isNotEmpty);
      expect(trouble.first, isA<StateError>());
    });
  });

  group('dispose', () {
    test('stops following', () async {
      await switchedOn();
      await families.save(familyOfFour());
      subject.start();
      await settle();
      final int planned = reminders.scheduleCalls;

      await subject.dispose();
      await families.save(familyOfFour());
      await settle();

      expect(reminders.scheduleCalls, planned);
    });
  });
}
