import 'package:cloud_firestore/cloud_firestore.dart';

class HealthLogService {
  static final _db = FirebaseFirestore.instance;

  // Saves a single reading to /users/{uid}/readings — converts epoch ms to Timestamp
  static Future<void> saveReading(
      String uid, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(
      data['timestamp'] as int,
    );
    await _db.collection('users').doc(uid).collection('readings').add(payload);
  }

  // Fetches all readings ordered by time — converts Timestamp back to epoch ms
  static Future<List<Map<String, dynamic>>> fetchReadings(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('readings')
        .orderBy('timestamp')
        .get();

    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      if (data['timestamp'] is Timestamp) {
        data['timestamp'] =
            (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
      }
      return data;
    }).toList();
  }
}
