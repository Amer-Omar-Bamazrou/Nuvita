import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../../features/medication/models/medication_model.dart';
import '../../features/medication/services/medication_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static const _channelId = 'medication_reminders';
  static const _channelName = 'Medication Reminders';
  static const _appointmentChannelId = 'appointment_reminders';
  static const _appointmentChannelName = 'Appointment Reminders';
  static const _lowSupplyChannelId = 'low_pill_supply';
  static const _lowSupplyChannelName = 'Low Pill Supply';
  static const _wellnessChannelId = 'wellness_reminders';
  static const _wellnessChannelName = 'Wellness Reminders';

  // Fixed ID above all other ranges — safe from collision
  static const _wellnessNotificationId = 1200001;

  // Registered from main.dart to avoid circular import:
  // appointment_service imports notification_service, so we can't import back.
  static Future<void> Function(String appointmentId)? _appointmentTapHandler;

  static void setAppointmentTapHandler(
      Future<void> Function(String appointmentId) handler) {
    _appointmentTapHandler = handler;
  }

  static Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;
    tz_data.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  // ── Notification tap routing ───────────────────────────────────────────────

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    if (payload.startsWith('med:')) {
      _handleMedicationTap(payload.substring(4));
    } else if (payload.startsWith('appt:')) {
      _appointmentTapHandler?.call(payload.substring(5));
    }
  }

  static Future<void> _handleMedicationTap(String medicationId) async {
    // Brief delay so the navigator is ready when the app opens from a tap
    await Future.delayed(const Duration(milliseconds: 500));

    if (_navigatorKey?.currentContext == null) return;
    final med = await MedicationService.getById(medicationId);
    if (med == null) return;

    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Did you take ${med.name}?'),
        content: Text(med.dosage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, I took it'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MedicationService.takeMedication(medicationId);
      final ctx = _navigatorKey?.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Great! ${med.name} marked as taken')),
        );
      }
    }
  }

  // ── Daily medication reminders (reminderEnabled toggle) ───────────────────

  static Future<void> scheduleDailyMedicationReminder(
    String medicationId,
    String medicationName,
    String dosage,
    List<String> times,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily reminders to take your medications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    for (int i = 0; i < times.length; i++) {
      final parts = times[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      await _plugin.zonedSchedule(
        _dailyReminderNotificationId(medicationId, i),
        'Medication Reminder',
        'Time to take $medicationName ($dosage)',
        _nextInstanceOfTime(hour, minute),
        details,
        payload: 'med:$medicationId',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> cancelDailyMedicationReminders(
    String medicationId,
    List<String> times,
  ) async {
    for (int i = 0; i < times.length; i++) {
      await _plugin.cancel(_dailyReminderNotificationId(medicationId, i));
    }
  }

  // ── Daily wellness reminder ────────────────────────────────────────────────

  static Future<void> scheduleDailyWellnessReminder() async {
    final androidDetails = AndroidNotificationDetails(
      _wellnessChannelId,
      _wellnessChannelName,
      channelDescription: 'Daily reminder to stay on track with your health',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      _wellnessNotificationId,
      'Wellness Check',
      'Remember to take your medications, log your readings, and stay active today.',
      _nextInstanceOfTime(9, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelWellnessReminder() async {
    await _plugin.cancel(_wellnessNotificationId);
  }

  // ── isActive-based reminders (existing — used by active toggle) ───────────

  static Future<void> scheduleMedicationReminder(MedicationModel med) async {
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

  // ── One-time appointment notification ─────────────────────────────────────

  // One-time notification at an absolute local time — used for appointment reminders
  static Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
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
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(String id) async {
    await _plugin.cancel(id.hashCode.abs() % 999990);
  }

  // ── Low supply alert ───────────────────────────────────────────────────────

  // One-time alert when a medication's pill count drops to 7 or below
  static Future<void> scheduleLowSupplyAlert(
      String id, String name, int remaining) async {
    final androidDetails = AndroidNotificationDetails(
      _lowSupplyChannelId,
      _lowSupplyChannelName,
      channelDescription: 'Alerts when pill supply is running low',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _lowSupplyNotificationId(id),
      'Low Pill Supply',
      '$name is running low. You have $remaining pills left.',
      details,
    );
  }

  static Future<void> cancelLowSupplyAlert(String id) async {
    await _plugin.cancel(_lowSupplyNotificationId(id));
  }

  // ── ID helpers ─────────────────────────────────────────────────────────────

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

  // isActive-based reminders — range 0–100,000
  static int _notificationId(String medicationId, int timeIndex) {
    return (medicationId.hashCode.abs() % 99990) + timeIndex;
  }

  // reminderEnabled-based daily reminders — range 1,100,000–1,200,000
  static int _dailyReminderNotificationId(String medicationId, int timeIndex) {
    return 1100000 + (medicationId.hashCode.abs() % 99990) + timeIndex;
  }

  // Range 999,991–1,099,980 — above appointment IDs (0–999,989)
  static int _lowSupplyNotificationId(String id) {
    return id.hashCode.abs() % 99990 + 999991;
  }
}
