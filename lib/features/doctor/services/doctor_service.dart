import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Returns true if the signed-in uid has a document in /doctors
  Future<bool> isDoctorAccount(String uid) async {
    final doc = await _db.collection('doctors').doc(uid).get();
    return doc.exists;
  }

  // Returns doctor's display name from /doctors/{uid}, falls back to email
  Future<String> getDoctorName(String uid, {String fallback = ''}) async {
    try {
      final doc = await _db.collection('doctors').doc(uid).get();
      return doc.data()?['name'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  // Returns all active user documents (active != false) from /users
  Future<List<Map<String, dynamic>>> getAllPatients() async {
    final snap = await _db.collection('users').get();
    return snap.docs
        .where((d) => d.data()['active'] != false)
        .map((d) => {'uid': d.id, ...d.data()})
        .toList();
  }

  // Last 10 readings for a patient, newest first
  Future<List<Map<String, dynamic>>> getPatientReadings(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // All active medications for a patient
  Future<List<Map<String, dynamic>>> getPatientMedications(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // Partial update on a medication document
  Future<void> updateMedication(
    String uid,
    String medId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc(medId)
        .update(data);
  }

  // Adds a new medication to /users/{uid}/medications (assigned by doctor)
  Future<void> addMedication(String uid, Map<String, dynamic> data) async {
    final docRef = _db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .doc();
    await docRef.set({
      'id': docRef.id,
      'isActive': true,
      ...data,
    });
  }

  // Saves a doctor suggestion to /users/{uid}/suggestions
  Future<void> sendSuggestion(
    String uid,
    String text,
    String doctorName, {
    String patientName = '',
    String patientId = '',
  }) async {
    await _db.collection('users').doc(uid).collection('suggestions').add({
      'text': text,
      'doctorName': doctorName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      if (patientName.isNotEmpty) 'patientName': patientName,
      if (patientId.isNotEmpty) 'patientId': patientId,
    });
  }

  // All suggestions sent by this doctor, newest first.
  Future<List<Map<String, dynamic>>> getSentSuggestionsHistory(
      String doctorName) async {
    final patients = await getAllPatients();
    final results = <Map<String, dynamic>>[];

    for (final patient in patients) {
      final uid = patient['uid'] as String;
      final patientName = patient['name'] as String? ??
          (patient['profile'] as Map?)?['name'] as String? ??
          'Unknown';
      final patientId = patient['patientId'] as String? ?? '—';

      try {
        final snap = await _db
            .collection('users')
            .doc(uid)
            .collection('suggestions')
            .where('doctorName', isEqualTo: doctorName)
            .get();

        for (final doc in snap.docs) {
          results.add({
            'id': doc.id,
            'patientUid': uid,
            'patientName': doc.data()['patientName'] ?? patientName,
            'patientId': doc.data()['patientId'] ?? patientId,
            ...doc.data(),
          });
        }
      } catch (e) {
        debugPrint('getSentSuggestionsHistory for $uid: $e');
      }
    }

    results.sort((a, b) {
      final aTs = a['timestamp'];
      final bTs = b['timestamp'];
      if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
      return 0;
    });

    return results;
  }

  // Total suggestions sent by this doctor
  Future<int> getTotalSuggestionsCount(String doctorName) async {
    final history = await getSentSuggestionsHistory(doctorName);
    return history.length;
  }

  // Emergency alerts fired today (cancelled == false) across all patients.
  // Only filters by timestamp in Firestore to avoid requiring a composite index;
  // cancelled is filtered client-side.
  Future<List<Map<String, dynamic>>> getEmergencyAlertsToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final snap = await _db
          .collectionGroup('alerts')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .get();

      final results = snap.docs
          .where((d) => d.data()['cancelled'] == false)
          .map((d) {
            final uid = d.reference.parent.parent?.id ?? '';
            return {'id': d.id, 'patientUid': uid, ...d.data()};
          })
          .toList();

      results.sort((a, b) {
        final aTs = a['timestamp'];
        final bTs = b['timestamp'];
        if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
        return 0;
      });

      return results;
    } catch (e) {
      debugPrint('getEmergencyAlertsToday: $e');
      return [];
    }
  }

  // Real-time stream of today's non-cancelled emergency alerts.
  // Single-field timestamp filter only — no composite index needed.
  Stream<List<Map<String, dynamic>>> streamEmergencyAlertsToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _db
        .collectionGroup('alerts')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .snapshots()
        .map((snap) {
          final results = snap.docs
              .where((d) => d.data()['cancelled'] == false)
              .map((d) {
                final uid = d.reference.parent.parent?.id ?? '';
                return {'id': d.id, 'patientUid': uid, ...d.data()};
              })
              .toList();
          results.sort((a, b) {
            final aTs = a['timestamp'];
            final bTs = b['timestamp'];
            if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
            return 0;
          });
          return results;
        });
  }

  // Stream of today's critical alert count for the overview stat card.
  Stream<int> streamCriticalAlertsCount() =>
      streamEmergencyAlertsToday().map((list) => list.length);

  // Count of medications with pillsRemaining <= 7 across all patients
  Future<int> getLowMedicationsCount() async {
    final patients = await getAllPatients();
    int count = 0;
    for (final p in patients) {
      final meds = await getPatientMedications(p['uid'] as String);
      for (final m in meds) {
        final pills = m['pillsRemaining'];
        if (pills != null && (pills as int) <= 7) count++;
      }
    }
    return count;
  }

  // Recent readings across all patients — up to 10, newest first
  Future<List<Map<String, dynamic>>> getRecentReadingsAllPatients() async {
    final snap = await _db
        .collectionGroup('readings')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return snap.docs.map((d) {
      final uid = d.reference.parent.parent?.id ?? '';
      return {'id': d.id, 'patientUid': uid, ...d.data()};
    }).toList();
  }

  // ── Patient Adherence ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPatientAdherence(
      String uid, int days) async {
    final now = DateTime.now();
    final startDate =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final startStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('adherence')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('getPatientAdherence: $e');
      return [];
    }
  }

  // ── Patient Messages (Mod 2) ───────────────────────────────────────────────

  // Stream of all patient messages, newest first
  Stream<List<Map<String, dynamic>>> getPatientMessages() {
    return _db
        .collectionGroup('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final uid = d.reference.parent.parent?.id ?? '';
              return {'id': d.id, 'patientUid': uid, ...d.data()};
            }).toList());
  }

  // Mark a patient message as read by the doctor
  Future<void> markMessageAsRead(String patientUid, String msgId) async {
    await _db
        .collection('users')
        .doc(patientUid)
        .collection('messages')
        .doc(msgId)
        .update({'readByDoctor': true});
  }

  // Real-time count of unread patient messages
  Stream<int> getUnreadMessagesCount() {
    return _db
        .collectionGroup('messages')
        .where('readByDoctor', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Patient Deactivation (Mod 5) ───────────────────────────────────────────

  Future<void> deactivatePatient(String uid, String doctorName) async {
    await _db.collection('users').doc(uid).update({
      'active': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': doctorName,
    });
  }

  Future<void> restorePatient(String uid) async {
    await _db.collection('users').doc(uid).update({
      'active': true,
      'deletedAt': FieldValue.delete(),
      'deletedBy': FieldValue.delete(),
    });
  }

  Future<List<Map<String, dynamic>>> getDeactivatedPatients() async {
    final snap = await _db
        .collection('users')
        .where('active', isEqualTo: false)
        .get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }
}
