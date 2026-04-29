import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appointment_model.dart';
import '../../../core/services/notification_service.dart';

class AppointmentService {
  static const _key = 'appointments_list';

  static Future<void> saveAppointment(AppointmentModel appointment) async {
    final list = await getAppointments();
    list.add(appointment);
    await _saveAll(list);
  }

  static Future<List<AppointmentModel>> getAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((a) => AppointmentModel.fromMap(a as Map<String, dynamic>))
        .toList();
  }

  // dateTime >= today, sorted soonest first
  static Future<List<AppointmentModel>> getUpcomingAppointments() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = await getAppointments();
    return list
        .where((a) => !a.dateTime.isBefore(today))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // dateTime < today, sorted most recent first
  static Future<List<AppointmentModel>> getPastAppointments() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = await getAppointments();
    return list
        .where((a) => a.dateTime.isBefore(today))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  static Future<void> deleteAppointment(String id) async {
    await cancelReminder(id);
    final list = await getAppointments();
    list.removeWhere((a) => a.id == id);
    await _saveAll(list);
  }

  static Future<void> markAsCompleted(String id) async {
    final list = await getAppointments();
    final i = list.indexWhere((a) => a.id == id);
    if (i != -1) {
      list[i] = list[i].copyWith(isCompleted: true);
      await _saveAll(list);
      await cancelReminder(id);
    }
  }

  static Future<void> scheduleReminder(AppointmentModel appointment) async {
    final reminderTime = appointment.dateTime
        .subtract(Duration(minutes: appointment.reminderMinutes));
    await NotificationService.initialize();
    await NotificationService.scheduleNotification(
      id: appointment.id,
      title: 'Appointment Reminder',
      body: 'Your appointment with ${appointment.doctorName} is coming up',
      scheduledDate: reminderTime,
    );
  }

  static Future<void> cancelReminder(String id) async {
    await NotificationService.cancelNotification(id);
  }

  static Future<void> _saveAll(List<AppointmentModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((a) => a.toMap()).toList()),
    );
  }
}
