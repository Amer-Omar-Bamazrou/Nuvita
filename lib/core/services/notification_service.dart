import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../../features/medication/models/medication_model.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'medication_reminders';
  static const _channelName = 'Medication Reminders';

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleMedicationReminder(
      MedicationModel med) async {
    if (!med.isActive) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily reminders to take your medications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    for (int i = 0; i < med.times.length; i++) {
      final parts = med.times[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      await _plugin.zonedSchedule(
        _notificationId(med.id, i),
        med.name,
        'Time to take ${med.dosage}',
        _nextInstanceOfTime(hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> cancelMedicationReminder(
      String medicationId, int timeCount) async {
    for (int i = 0; i < timeCount; i++) {
      await _plugin.cancel(_notificationId(medicationId, i));
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // Builds the next scheduled TZDateTime for a given hour:minute in local time.
  // Converts local → UTC so the daily repeat fires at the correct local time.
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    var local = DateTime(now.year, now.month, now.day, hour, minute);
    if (local.isBefore(now)) {
      local = local.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(local.toUtc(), tz.UTC);
  }

  // One-time notification at an absolute local time — used for appointment reminders
  static Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Skip if the reminder time has already passed
    if (scheduledDate.isBefore(DateTime.now())) return;

    final androidDetails = AndroidNotificationDetails(
      _appointmentChannelId,
      _appointmentChannelName,
      channelDescription: 'Reminders for upcoming doctor appointments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id.hashCode.abs() % 999990,
      title,
      body,
      tz.TZDateTime.from(scheduledDate.toUtc(), tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(String id) async {
    await _plugin.cancel(id.hashCode.abs() % 999990);
  }

  // Deterministic int ID per medication + time slot so we can cancel reliably
  static int _notificationId(String medicationId, int timeIndex) {
    return (medicationId.hashCode.abs() % 99990) + timeIndex;
  }

  static const _appointmentChannelId = 'appointment_reminders';
  static const _appointmentChannelName = 'Appointment Reminders';
}
