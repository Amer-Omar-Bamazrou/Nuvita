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

  // Returns all user documents from /users as raw maps
  Future<List<Map<String, dynamic>>> getAllPatients() async {
    final snap = await _db.collection('users').get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
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

  // Saves a doctor suggestion to /users/{uid}/suggestions
  Future<void> sendSuggestion(
    String uid,
    String text,
    String doctorName,
  ) async {
    await _db.collection('users').doc(uid).collection('suggestions').add({
      'text': text,
      'doctorName': doctorName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // Count of Critical/High readings across all patients today (in-memory filter)
  Future<int> getCriticalReadingsCount() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final snap = await _db
        .collectionGroup('readings')
        .where('status', whereIn: ['Critical', 'High', 'Low'])
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    return snap.docs.length;
  }

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

  // Total suggestions sent by this doctor to all patients
  Future<int> getTotalSuggestionsCount(String doctorName) async {
    final snap = await _db
        .collectionGroup('suggestions')
        .where('doctorName', isEqualTo: doctorName)
        .get();
    return snap.docs.length;
  }

  // Recent readings across all patients — up to 10, newest first
  Future<List<Map<String, dynamic>>> getRecentReadingsAllPatients() async {
    final snap = await _db
        .collectionGroup('readings')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    // Attach patient uid from the document reference path
    return snap.docs.map((d) {
      final uid = d.reference.parent.parent?.id ?? '';
      return {'id': d.id, 'patientUid': uid, ...d.data()};
    }).toList();
  }
}
