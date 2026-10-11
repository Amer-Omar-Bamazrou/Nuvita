import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/health/health_metrics.dart';
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

  // Saves readings taken together (e.g. systolic + diastolic) in one batch so
  // either all of them are written or none. Returns them with their new IDs.
  static Future<List<HealthReading>> saveReadings(
      String uid, List<HealthReading> readings) async {
    final batch = FirebaseFirestore.instance.batch();
    final saved = <HealthReading>[];
    for (final r in readings) {
      final ref = _col(uid).doc();
      batch.set(ref, r.toMap());
      saved.add(HealthReading(
        id: ref.id,
        metricType: r.metricType,
        value: r.value,
        unit: r.unit,
        status: r.status,
        timestamp: r.timestamp,
        note: r.note,
        context: r.context,
      ));
    }
    await batch.commit();
    return saved;
  }

  // Live query of the newest [limit] readings. Firestore delivers local
  // writes straight away, so saves, edits and deletes show up without a
  // reload; changes made elsewhere (e.g. by the doctor) arrive the same way.
  static Stream<List<HealthReading>> watchReadings(String uid,
      {required int limit}) {
    return _col(uid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .where((d) => d.data()['value'] is num)
            .map((d) => HealthReading.fromMap(d.id, d.data()))
            .toList());
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

  // Every reading the user has, newest first (used by data export)
  static Future<List<HealthReading>> getAllReadings(String uid) async {
    final snap = await _col(uid).orderBy('timestamp', descending: true).get();
    return snap.docs
        .where((d) => d.data()['value'] is num)
        .map((d) => HealthReading.fromMap(d.id, d.data()))
        .toList();
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
  // Fetches only that metric's documents (legacy keys included) and picks the
  // latest in Dart to avoid requiring a (metricType + timestamp) composite index.
  static Future<HealthReading?> getLatestReading(
      String uid, String metricType) async {
    final metric = HealthMetrics.metricForKey(metricType);
    final keys =
        metric == null ? [metricType] : HealthMetrics.storedKeysFor(metric);
    final snap = await _col(uid)
        .where('metricType', whereIn: keys)
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

  static Future<void> updateReading(
      String uid, String readingId, double newValue, String newStatus,
      {DateTime? timestamp}) async {
    final data = <String, dynamic>{
      'value': newValue,
      'status': newStatus,
    };
    if (timestamp != null) {
      data['timestamp'] = Timestamp.fromDate(timestamp);
    }
    await _col(uid).doc(readingId).update(data);
  }

  static Future<List<HealthReading>> getReadingsPaginated(
      String uid, {int limit = 30, DateTime? startAfter}) async {
    Query<Map<String, dynamic>> query = _col(uid)
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => HealthReading.fromMap(d.id, d.data()))
        .toList();
  }
}
