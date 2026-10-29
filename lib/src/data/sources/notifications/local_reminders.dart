import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../domain/reminders/reminder_plan.dart';
import 'reminders.dart';

/// Reminders delivered by the phone itself.
///
/// Local notifications rather than push, and not by preference: the free
/// Firebase plan cannot send a push at all without a server, and this project
/// has decided it will never have one (ADR-010). So each phone reminds the
/// person holding it, and the app has no way to notify anybody else —
/// a real limit, recorded rather than worked around.
class LocalReminders implements Reminders {
  LocalReminders({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'handover';
  static const String _channelName = 'Handover reminders';
  static const String _channelDescription =
      'Tells you the evening before your week to lead family prayer.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) {
      return;
    }
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for separately, when somebody switches reminders on.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureReady();

    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    return false;
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    await _ensureReady();
    await cancelAll();

    for (final Reminder reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ensureReady();
    await _plugin.cancelAll();
  }

  @override
  Future<Set<int>> pending() async {
    await _ensureReady();
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    return <int>{
      for (final PendingNotificationRequest request in pending) request.id,
    };
  }
}
