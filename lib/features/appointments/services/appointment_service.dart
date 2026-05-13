import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../../../core/services/notification_service.dart';

class AppointmentService {
  static const _key = 'appointments_list';

  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('appointments');

  static Future<void> saveAppointment(AppointmentModel appointment) async {
    final list = await getAppointments();
    list.add(appointment);
    await _saveAll(list);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await _saveToFirebase(uid, appointment);
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

  static Future<AppointmentModel?> getAppointmentById(String id) async {
    final list = await getAppointments();
    try {
      return list.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateAppointment(AppointmentModel updated) async {
    final list = await getAppointments();
    final i = list.indexWhere((a) => a.id == updated.id);
    if (i != -1) {
      list[i] = updated;
      await _saveAll(list);
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await _updateInFirebase(uid, updated);
  }

  static Future<void> deleteAppointment(String id) async {
    await cancelReminder(id);
    final list = await getAppointments();
    list.removeWhere((a) => a.id == id);
    await _saveAll(list);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await _deleteFromFirebase(uid, id);
  }

  static Future<void> markAsCompleted(String id) async {
    final list = await getAppointments();
    final i = list.indexWhere((a) => a.id == id);
    if (i != -1) {
      final updated = list[i].copyWith(isCompleted: true);
      list[i] = updated;
      await _saveAll(list);
      await cancelReminder(id);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _updateInFirebase(uid, updated);
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
      payload: 'appt:${appointment.id}',
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

  // ── Firebase sync ──

  static Future<void> _saveToFirebase(
      String uid, AppointmentModel appointment) async {
    try {
      await _col(uid).doc(appointment.id).set(_toFirestoreMap(appointment));
    } catch (_) {}
  }

  static Future<void> _updateInFirebase(
      String uid, AppointmentModel appointment) async {
    try {
      await _col(uid).doc(appointment.id).update(_toFirestoreMap(appointment));
    } catch (_) {}
  }

  static Future<void> _deleteFromFirebase(String uid, String id) async {
    try {
      await _col(uid).doc(id).delete();
    } catch (_) {}
  }

  static Future<void> syncFromFirebase(String uid) async {
    try {
      final snap = await _col(uid).get();
      final remote = snap.docs
          .map((d) => _fromFirestoreDoc(d.id, d.data()))
          .toList();

      final local = await getAppointments();
      final remoteIds = remote.map((a) => a.id).toSet();

      // Firestore wins on same ID; local-only entries preserved
      final merged = <AppointmentModel>[...remote];
      for (final l in local) {
        if (!remoteIds.contains(l.id)) merged.add(l);
      }

      await _saveAll(merged);
    } catch (_) {}
  }

  static Map<String, dynamic> _toFirestoreMap(AppointmentModel a) => {
        'id': a.id,
        'doctorName': a.doctorName,
        'speciality': a.speciality,
        'location': a.location,
        'dateTime': Timestamp.fromDate(a.dateTime),
        'notes': a.notes,
        'reminderMinutes': a.reminderMinutes,
        'isCompleted': a.isCompleted,
        'isConfirmed': a.isConfirmed,
      };

  static AppointmentModel _fromFirestoreDoc(
      String docId, Map<String, dynamic> map) {
    final ts = map['dateTime'];
    final DateTime dt = ts is Timestamp
        ? ts.toDate()
        : DateTime.parse(ts as String);

    return AppointmentModel(
      id: map['id'] as String? ?? docId,
      doctorName: map['doctorName'] as String? ?? '',
      speciality: map['speciality'] as String? ?? '',
      location: map['location'] as String? ?? '',
      dateTime: dt,
      notes: map['notes'] as String? ?? '',
      reminderMinutes: map['reminderMinutes'] as int? ?? 60,
      isCompleted: map['isCompleted'] as bool? ?? false,
      isConfirmed: map['isConfirmed'] as bool? ?? false,
    );
  }
}
