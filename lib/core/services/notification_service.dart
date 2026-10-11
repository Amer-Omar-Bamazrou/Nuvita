import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../../features/medication/models/medication_model.dart';
import '../../features/medication/services/medication_service.dart';
import '../../features/medication/services/dose_service.dart';
import '../../features/appointments/services/appointment_service.dart';
import 'care_services.dart';
import 'reminder_time.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  // The device's zone. When it can't be resolved this is a fixed-offset
  // stand-in and _zoneResolved is false.
  static tz.Location _zone = tz.UTC;
  static bool _zoneResolved = false;

  // ── Channels ──────────────────────────────────────────────────────────────

  static const _channelId = 'medication_reminders';
  static const _channelName = 'Medication Reminders';
  static const _appointmentChannelId = 'appointment_reminders';
  static const _appointmentChannelName = 'Appointment Reminders';
  static const _lowSupplyChannelId = 'low_pill_supply';
  static const _lowSupplyChannelName = 'Low Pill Supply';
  static const _wellnessChannelId = 'wellness_reminders';
  static const _wellnessChannelName = 'Wellness Reminders';
  static const _criticalChannelId = 'critical_readings';
  static const _criticalChannelName = 'Critical Readings';
  static const _doctorChannelId = 'doctor_notifications';
  static const _doctorChannelName = 'Doctor Notifications';
  static const _weeklySummaryChannelId = 'weekly_summary';
  static const _weeklySummaryChannelName = 'Weekly Summary';
  static const _missedDoseChannelId = 'missed_dose';
  static const _missedDoseChannelName = 'Missed Dose Alerts';

  // ── Fixed IDs ─────────────────────────────────────────────────────────────

  static const _wellnessNotificationId = 1200001;
  static const _weeklySummaryNotificationId = 1500001;

  // ── ID Ranges ─────────────────────────────────────────────────────────────
  // 0–99,999           isActive reminders
  // 0–999,989          legacy one-time (scheduleNotification)
  // 999,991–1,099,980  low supply
  // 1,100,000–1,199,999 daily med reminders
  // 1,200,001          wellness
  // 1,300,000–1,399,999 missed dose alerts
  // 1,400,000–1,499,999 appointment tomorrow
  // 1,500,001          weekly summary
  // 1,600,000–1,699,999 follow-up notifications
  // 1,700,000–1,799,999 critical reading
  // 1,800,000–1,899,999 doctor assigned med
  // 1,900,000–1,999,999 doctor suggestion
  // 2,000,000–2,099,999 snoozed med reminders
  // 2,100,000–2,199,999 appointment reminders

  // ── Tap handlers (set from main.dart to avoid circular imports) ───────────

  static Future<void> Function(String appointmentId)? _appointmentTapHandler;
  static VoidCallback? _suggestionsPanelHandler;
  static Future<void> Function(String medicationId)? _medicationDetailHandler;

  static void setAppointmentTapHandler(
      Future<void> Function(String appointmentId) handler) {
    _appointmentTapHandler = handler;
  }

  static void setSuggestionsPanelHandler(VoidCallback handler) {
    _suggestionsPanelHandler = handler;
  }

  static void setMedicationDetailHandler(
      Future<void> Function(String medicationId) handler) {
    _medicationDetailHandler = handler;
  }

  // ── Initialize ────────────────────────────────────────────────────────────

  static Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;
    await _configureLocalTimeZone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundAction,
    );
    _initialized = true;
  }

  // Points tz.local at the device's zone so repeating reminders are scheduled
  // in local time and keep their wall-clock time across daylight-saving
  // changes. Every isolate that schedules notifications must call this.
  static Future<void> _configureLocalTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      _zone = tz.getLocation(info.identifier);
      tz.setLocalLocation(_zone);
      _zoneResolved = true;
    } catch (e) {
      debugPrint('NotificationService: device timezone unavailable: $e');
      _zone = fixedOffsetLocation(DateTime.now().timeZoneOffset);
      _zoneResolved = false;
    }
  }

  // The fixed-offset stand-in has no name Android recognises, so in that
  // case hand the plugin the same instant in UTC (the old behaviour).
  static tz.TZDateTime _forPlugin(tz.TZDateTime time) =>
      _zoneResolved ? time : tz.TZDateTime.from(time, tz.UTC);

  // A one-off local DateTime as a zoned time for the plugin
  static tz.TZDateTime _at(DateTime local) =>
      _forPlugin(tz.TZDateTime.from(local, _zone));

  static Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  // ── Foreground notification tap routing ────────────────────────────────────

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    // Reschedule action opens app to appointment detail
    if (response.actionId == 'appt_reschedule') {
      final apptId = payload.replaceFirst('appt:', '');
      _appointmentTapHandler?.call(apptId);
      return;
    }

    if (payload.startsWith('med:')) {
      final parts = payload.split(':');
      // med:{medId}:{HH}:{mm} — the slot itself contains a colon
      final slot = parts.length >= 4 ? '${parts[2]}:${parts[3]}' : null;
      _handleMedicationTap(parts[1], slot);
    } else if (payload.startsWith('appt:') || payload.startsWith('tomorrow:')) {
      _appointmentTapHandler?.call(payload.split(':')[1]);
    } else if (payload.startsWith('missed:')) {
      // missed:{medId}:{time} → open medication detail
      _medicationDetailHandler?.call(payload.split(':')[1]);
    } else if (payload.startsWith('docmed:')) {
      _medicationDetailHandler?.call(payload.split(':')[1]);
    } else if (payload.startsWith('critical:')) {
      _suggestionsPanelHandler?.call();
    } else if (payload.startsWith('suggestion:') || payload == 'weekly') {
      _suggestionsPanelHandler?.call();
    }
  }

  static Future<void> _handleMedicationTap(
      String medicationId, String? timeSlot) async {
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
      final slot = timeSlot ?? await DoseService.nextUntakenSlot(med);
      if (slot != null) {
        await DoseService.markTaken(medicationId: medicationId, timeSlot: slot);
      }
      final ctx = _navigatorKey?.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Great! ${med.name} marked as taken')),
        );
      }
    }
  }

  // ── Background action handler ─────────────────────────────────────────────

  @pragma('vm:entry-point')
  static void _onBackgroundAction(NotificationResponse response) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('NotificationService: Firebase init failed: $e');
    }

    // Background isolates start without the zone set up
    await _configureLocalTimeZone();

    // Plugin needs init in background isolate to schedule/show notifications
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    final payload = response.payload ?? '';

    switch (response.actionId) {
      case 'med_taken':
        await _bgMedTaken(payload);
        break;
      case 'med_snooze':
        await _bgMedSnooze(payload);
        break;
      case 'med_undo':
        await _bgMedUndo(payload);
        break;
      case 'supply_refilled':
        await _bgSupplyRefilled(payload);
        break;
      case 'supply_remind':
        await _bgSupplyRemind(payload);
        break;
      case 'appt_confirm':
        await _bgApptConfirm(payload);
        break;
    }
  }

  // payload: med:{medId}:{HH}:{mm}
  static Future<void> _bgMedTaken(String payload) async {
    final parts = payload.split(':');
    if (parts.length < 4) return;
    final medId = parts[1];
    final time = '${parts[2]}:${parts[3]}';
    final date = DoseService.dateKey(DateTime.now());

    final updated = await DoseService.markTaken(medicationId: medId, timeSlot: time);
    if (updated == null) return;

    // Follow-up confirmation with a way to take it back
    await _showFollowUp(
      '${updated.name} marked as taken ✅',
      payload: 'taken:$medId:$time:$date',
      actions: _takenFollowUpActions,
    );
  }

  // payload: taken:{medId}:{HH}:{mm}:{yyyy-MM-dd}
  static Future<void> _bgMedUndo(String payload) async {
    final parts = payload.split(':');
    if (parts.length < 5) return;
    final day = DateTime.tryParse(parts[4]);
    final med = await DoseService.undo(
      medicationId: parts[1],
      timeSlot: '${parts[2]}:${parts[3]}',
      day: day,
    );
    if (med == null) return;
    await _showFollowUp('${med.name} dose undone');
  }

  // payload: med:{medId}:{time}
  static Future<void> _bgMedSnooze(String payload) async {
    final parts = payload.split(':');
    if (parts.length < 3) return;
    final medId = parts[1];

    final med = await MedicationService.getById(medId);
    if (med == null) return;

    // Reschedule 15 min from now
    final snoozeTime = DateTime.now().add(const Duration(minutes: 15));

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily reminders to take your medications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: _medReminderActions,
    );

    await _plugin.zonedSchedule(
      _snoozedMedNotificationId(medId),
      'Medication Reminder',
      'Time to take ${med.name}\n${med.dosage} — Take ${med.pillsPerDose} pill${med.pillsPerDose > 1 ? 's' : ''}',
      _at(snoozeTime),
      NotificationDetails(android: androidDetails),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    await _showFollowUp('Reminder snoozed — 15 minutes');
  }

  // payload: supply:{medId}
  static Future<void> _bgSupplyRefilled(String payload) async {
    final medId = payload.replaceFirst('supply:', '');

    final med = await MedicationService.getById(medId);
    if (med == null) return;

    final updated = med.copyWith(
      pillsRemaining: 30,
      lowSupplyNotified: false,
    );
    await MedicationService.update(updated);
    await cancelLowSupplyAlert(medId);

    await _showFollowUp('${med.name} refilled — 30 pills ✅');
  }

  // payload: supply:{medId}
  static Future<void> _bgSupplyRemind(String payload) async {
    final medId = payload.replaceFirst('supply:', '');

    final med = await MedicationService.getById(medId);
    if (med == null) return;

    // Reschedule low supply alert for 24 hours from now
    final remindTime = DateTime.now().add(const Duration(hours: 24));

    final androidDetails = AndroidNotificationDetails(
      _lowSupplyChannelId,
      _lowSupplyChannelName,
      channelDescription: 'Alerts when pill supply is running low',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: _lowSupplyActions,
    );

    await _plugin.zonedSchedule(
      _lowSupplyNotificationId(medId),
      'Low Pill Supply',
      '${med.name} is running low.\n${med.pillsRemaining ?? 0} pills remaining.',
      _at(remindTime),
      NotificationDetails(android: androidDetails),
      payload: 'supply:$medId',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    await _showFollowUp("We'll remind you tomorrow");
  }

  // payload: appt:{apptId}
  static Future<void> _bgApptConfirm(String payload) async {
    final apptId = payload.replaceFirst('appt:', '');

    final appt = await AppointmentService.getAppointmentById(apptId);
    if (appt == null) return;

    final updated = appt.copyWith(isConfirmed: true);
    await AppointmentService.updateAppointment(updated);

    final hour = updated.dateTime.hour.toString().padLeft(2, '0');
    final minute = updated.dateTime.minute.toString().padLeft(2, '0');
    await _showFollowUp('Appointment confirmed — See you at $hour:$minute ✅');
  }

  static Future<void> _showFollowUp(
    String message, {
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Confirmation notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      actions: actions,
    );

    await _plugin.show(
      _followUpId(),
      'Nuvita',
      message,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  // ── Action button definitions ─────────────────────────────────────────────

  static const _medReminderActions = <AndroidNotificationAction>[
    AndroidNotificationAction(
      'med_taken',
      '✓ Taken',
      showsUserInterface: false,
    ),
    AndroidNotificationAction(
      'med_snooze',
      '⏰ Snooze',
      showsUserInterface: false,
    ),
  ];

  static const _takenFollowUpActions = <AndroidNotificationAction>[
    AndroidNotificationAction(
      'med_undo',
      '↩ Undo',
      showsUserInterface: false,
    ),
  ];

  static const _lowSupplyActions = <AndroidNotificationAction>[
    AndroidNotificationAction(
      'supply_refilled',
      '💊 Refilled',
      showsUserInterface: false,
    ),
    AndroidNotificationAction(
      'supply_remind',
      '⏰ Remind',
      showsUserInterface: false,
    ),
  ];

  static const _appointmentActions = <AndroidNotificationAction>[
    AndroidNotificationAction(
      'appt_confirm',
      '✓ Confirm',
      showsUserInterface: false,
    ),
    AndroidNotificationAction(
      'appt_reschedule',
      '🔄 Reschedule',
      showsUserInterface: true,
    ),
  ];

  // ── 5. Daily medication reminders (reminderEnabled toggle) ────────────────

  static Future<void> scheduleDailyMedicationReminder(
    String medicationId,
    String medicationName,
    String dosage,
    List<String> times, {
    int pillsPerDose = 1,
  }) async {
    if (!await CareServices.isEnabled(CareServices.medications)) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily reminders to take your medications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: _medReminderActions,
    );
    final details = NotificationDetails(android: androidDetails);

    for (int i = 0; i < times.length; i++) {
      final parts = times[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      await _plugin.zonedSchedule(
        _dailyReminderNotificationId(medicationId, i),
        'Medication Reminder',
        'Time to take $medicationName\n$dosage — Take $pillsPerDose pill${pillsPerDose > 1 ? 's' : ''}',
        _nextInstanceOfTime(hour, minute),
        details,
        payload: 'med:$medicationId:${times[i]}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // Also schedule missed dose alerts (+30min per dose)
    await scheduleMissedDoseAlerts(medicationId, medicationName, dosage, times);
  }

  static Future<void> cancelDailyMedicationReminders(
    String medicationId,
    List<String> times,
  ) async {
    for (int i = 0; i < times.length; i++) {
      await _plugin.cancel(_dailyReminderNotificationId(medicationId, i));
    }
    await cancelMissedDoseAlerts(medicationId, times);
  }

  // ── 6. Low supply alert ───────────────────────────────────────────────────

  static Future<void> scheduleLowSupplyAlert(
      String id, String name, int remaining) async {
    if (!await CareServices.isEnabled(CareServices.medications)) return;

    final androidDetails = AndroidNotificationDetails(
      _lowSupplyChannelId,
      _lowSupplyChannelName,
      channelDescription: 'Alerts when pill supply is running low',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: _lowSupplyActions,
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _lowSupplyNotificationId(id),
      'Low Pill Supply',
      '$name is running low.\n$remaining pills remaining.',
      details,
      payload: 'supply:$id',
    );
  }

  static Future<void> cancelLowSupplyAlert(String id) async {
    await _plugin.cancel(_lowSupplyNotificationId(id));
  }

  // ── 7. Appointment reminder with actions ──────────────────────────────────

  static Future<void> scheduleAppointmentReminder({
    required String id,
    required String doctorName,
    required String speciality,
    required DateTime scheduledDate,
    required DateTime appointmentDateTime,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;
    if (!await CareServices.isEnabled(CareServices.appointments)) return;

    final hour = appointmentDateTime.hour.toString().padLeft(2, '0');
    final minute = appointmentDateTime.minute.toString().padLeft(2, '0');

    final androidDetails = AndroidNotificationDetails(
      _appointmentChannelId,
      _appointmentChannelName,
      channelDescription: 'Reminders for upcoming doctor appointments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: _appointmentActions,
    );

    await _plugin.zonedSchedule(
      _appointmentNotificationId(id),
      'Appointment Reminder',
      'Dr. $doctorName — $speciality\nAppointment at $hour:$minute',
      _at(scheduledDate),
      NotificationDetails(android: androidDetails),
      payload: 'appt:$id',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAppointmentReminder(String id) async {
    await _plugin.cancel(_appointmentNotificationId(id));
  }

  // ── 8. Doctor assigned medication (plain) ─────────────────────────────────

  static Future<void> showDoctorAssignedMedNotification({
    required String medId,
    required String doctorName,
    required String medName,
    required String dosage,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _doctorChannelId,
      _doctorChannelName,
      channelDescription: 'Notifications from your doctor',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      _doctorMedNotificationId(medId),
      'New Medication Assigned',
      'Dr. $doctorName assigned $medName $dosage',
      NotificationDetails(android: androidDetails),
      payload: 'docmed:$medId',
    );
  }

  // ── 9. Doctor sent suggestion (plain) ─────────────────────────────────────

  static Future<void> showDoctorSuggestionNotification({
    required String suggestionId,
    required String doctorName,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _doctorChannelId,
      _doctorChannelName,
      channelDescription: 'Notifications from your doctor',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      _doctorSuggestionNotificationId(suggestionId),
      'Message from Your Doctor',
      'Dr. $doctorName sent you a health recommendation',
      NotificationDetails(android: androidDetails),
      payload: 'suggestion:$suggestionId',
    );
  }

  // ── 10. Critical reading warning (plain) ──────────────────────────────────

  static Future<void> showCriticalReadingNotification({
    required String readingId,
    required String metricName,
    required double value,
    required String unit,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _criticalChannelId,
      _criticalChannelName,
      channelDescription: 'Alerts for critical health readings',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      _criticalReadingNotificationId(readingId),
      '⚠️ Critical Reading',
      'Your $metricName reading of ${value.toStringAsFixed(0)} $unit is critical.\nPlease rest and seek medical attention if needed.',
      NotificationDetails(android: androidDetails),
      payload: 'critical:$readingId',
    );
  }

  // ── 11. Weekly health summary ─────────────────────────────────────────────

  static Future<void> scheduleWeeklyHealthSummary() async {
    // The summary is about readings and adherence
    final services = await CareServices.load();
    if (!services.contains(CareServices.measurements) &&
        !services.contains(CareServices.medications)) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _weeklySummaryChannelId,
      _weeklySummaryChannelName,
      channelDescription: 'Weekly health summary reminder',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    // Sunday at 10:00 AM
    await _plugin.zonedSchedule(
      _weeklySummaryNotificationId,
      'Weekly Health Summary',
      'Check your weekly health trends and adherence in Nuvita',
      _nextInstanceOfDayAndTime(DateTime.sunday, 10, 0),
      NotificationDetails(android: androidDetails),
      payload: 'weekly',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelWeeklyHealthSummary() async {
    await _plugin.cancel(_weeklySummaryNotificationId);
  }

  // ── 12. Missed dose alerts ────────────────────────────────────────────────

  static Future<void> scheduleMissedDoseAlerts(
    String medicationId,
    String medicationName,
    String dosage,
    List<String> times,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      _missedDoseChannelId,
      _missedDoseChannelName,
      channelDescription: 'Alerts for missed medication doses',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    for (int i = 0; i < times.length; i++) {
      final parts = times[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // 30 minutes after the dose time
      var missedHour = hour;
      var missedMinute = minute + 30;
      if (missedMinute >= 60) {
        missedHour++;
        missedMinute -= 60;
      }
      if (missedHour >= 24) missedHour -= 24;

      await _plugin.zonedSchedule(
        _missedDoseNotificationId(medicationId, i),
        'Missed Dose',
        'You missed $medicationName $dosage at ${times[i]}.\nTake it now if possible.',
        _nextInstanceOfTime(missedHour, missedMinute),
        details,
        payload: 'missed:$medicationId:${times[i]}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> cancelMissedDoseAlerts(
    String medicationId,
    List<String> times,
  ) async {
    for (int i = 0; i < times.length; i++) {
      await _plugin.cancel(_missedDoseNotificationId(medicationId, i));
    }
  }

  // ── 13. Appointment tomorrow reminder (plain) ─────────────────────────────

  static Future<void> scheduleAppointmentTomorrowReminder({
    required String id,
    required String doctorName,
    required String speciality,
    required DateTime appointmentDateTime,
  }) async {
    // Day before at 18:00
    final apptDate = DateTime(
      appointmentDateTime.year,
      appointmentDateTime.month,
      appointmentDateTime.day,
    );
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    // Skip if appointment is today (main reminder handles it)
    if (!apptDate.isAfter(today)) return;
    if (!await CareServices.isEnabled(CareServices.appointments)) return;

    final reminderDate = DateTime(
      apptDate.year,
      apptDate.month,
      apptDate.day - 1,
      18,
      0,
    );

    if (reminderDate.isBefore(DateTime.now())) return;

    final hour = appointmentDateTime.hour.toString().padLeft(2, '0');
    final minute = appointmentDateTime.minute.toString().padLeft(2, '0');

    final androidDetails = AndroidNotificationDetails(
      _appointmentChannelId,
      _appointmentChannelName,
      channelDescription: 'Reminders for upcoming doctor appointments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.zonedSchedule(
      _appointmentTomorrowNotificationId(id),
      'Appointment Tomorrow',
      'Reminder: Dr. $doctorName — $speciality\ntomorrow at $hour:$minute',
      _at(reminderDate),
      NotificationDetails(android: androidDetails),
      payload: 'tomorrow:$id',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAppointmentTomorrowReminder(String id) async {
    await _plugin.cancel(_appointmentTomorrowNotificationId(id));
  }

  // ── Daily wellness reminder ───────────────────────────────────────────────

  // The daily "stay on track" nudge is what the Activities service offers
  static Future<void> scheduleDailyWellnessReminder() async {
    if (!await CareServices.isEnabled(CareServices.activities)) return;

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
    if (!await CareServices.isEnabled(CareServices.medications)) return;

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

  // Cancels and re-creates every reminder from the stored medications and
  // appointments. Used when the chosen services change and after sign-in
  // (sign-out cancels everything). Each schedule call checks its service.
  static Future<void> rescheduleAll() async {
    await initialize();

    final meds = await MedicationService.loadAll();
    for (final med in meds) {
      await cancelMedicationReminder(med.id, med.times.length);
      await cancelDailyMedicationReminders(med.id, med.times);
      if (!med.isActive) continue;
      await scheduleMedicationReminder(med);
      if (med.reminderEnabled) {
        await scheduleDailyMedicationReminder(
          med.id,
          med.name,
          med.dosage,
          med.times,
          pillsPerDose: med.pillsPerDose,
        );
      }
    }

    final appointments = await AppointmentService.getUpcomingAppointments();
    for (final appt in appointments) {
      await AppointmentService.cancelReminder(appt.id);
      if (!appt.isCompleted) await AppointmentService.scheduleReminder(appt);
    }

    await cancelWellnessReminder();
    await scheduleDailyWellnessReminder();
    await cancelWeeklyHealthSummary();
    await scheduleWeeklyHealthSummary();
  }

  // ── Legacy one-time notification (kept for non-appointment callers) ───────

  static Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
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
      _at(scheduledDate),
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

  // ── Time helpers ──────────────────────────────────────────────────────────

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) =>
      _forPlugin(nextInstanceOfTime(_zone, hour, minute));

  static tz.TZDateTime _nextInstanceOfDayAndTime(
          int weekday, int hour, int minute) =>
      _forPlugin(nextInstanceOfDayAndTime(_zone, weekday, hour, minute));

  // ── ID helpers ────────────────────────────────────────────────────────────

  static int _notificationId(String medicationId, int timeIndex) {
    return (medicationId.hashCode.abs() % 99990) + timeIndex;
  }

  static int _dailyReminderNotificationId(String medicationId, int timeIndex) {
    return 1100000 + (medicationId.hashCode.abs() % 99990) + timeIndex;
  }

  static int _lowSupplyNotificationId(String id) {
    return id.hashCode.abs() % 99990 + 999991;
  }

  static int _missedDoseNotificationId(String medicationId, int timeIndex) {
    return 1300000 + (medicationId.hashCode.abs() % 99990) + timeIndex;
  }

  static int _appointmentNotificationId(String id) {
    return 2100000 + (id.hashCode.abs() % 99990);
  }

  static int _appointmentTomorrowNotificationId(String id) {
    return 1400000 + (id.hashCode.abs() % 99990);
  }

  static int _followUpId() {
    return 1600000 + (DateTime.now().millisecondsSinceEpoch % 99990);
  }

  static int _criticalReadingNotificationId(String readingId) {
    return 1700000 + (readingId.hashCode.abs() % 99990);
  }

  static int _doctorMedNotificationId(String medId) {
    return 1800000 + (medId.hashCode.abs() % 99990);
  }

  static int _doctorSuggestionNotificationId(String suggId) {
    return 1900000 + (suggId.hashCode.abs() % 99990);
  }

  static int _snoozedMedNotificationId(String medId) {
    return 2000000 + (medId.hashCode.abs() % 99990);
  }
}
