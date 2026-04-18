import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_reading.dart';

class HealthReadingService {
  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('readings');

  // Saves a reading document and returns the generated Firestore ID
  static Future<String> saveReading(String uid, HealthReading reading) async {
    final ref = await _col(uid).add(reading.toMap());
    return ref.id;
  }

  // Live stream of all readings, newest first
  static Stream<List<HealthReading>> getReadings(String uid) {
    return _col(uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => HealthReading.fromMap(d.id, d.data()))
            .toList());
  }

  // Fetches readings from the last N days, newest first.
  // Filtering is done client-side to avoid needing a composite Firestore index.
  static Future<List<HealthReading>> getReadingsLastDays(
      String uid, int days) async {
    final snap = await _col(uid)
        .orderBy('timestamp', descending: true)
        .get();

    final cutoff = DateTime.now().subtract(Duration(days: days));
    return snap.docs
        .map((d) => HealthReading.fromMap(d.id, d.data()))
        .where((r) => r.timestamp.isAfter(cutoff))
        .toList();
  }

  // Returns the single most recent reading for a given metric type.
  // Fetches only that metric's documents and picks the latest in Dart
  // to avoid requiring a (metricType + timestamp) composite index.
  static Future<HealthReading?> getLatestReading(
      String uid, String metricType) async {
    final snap = await _col(uid)
        .where('metricType', isEqualTo: metricType)
        .get();

    if (snap.docs.isEmpty) return null;

    final readings = snap.docs
        .map((d) => HealthReading.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return readings.first;
  }

  static Future<void> deleteReading(String uid, String readingId) async {
    await _col(uid).doc(readingId).delete();
  }
}
