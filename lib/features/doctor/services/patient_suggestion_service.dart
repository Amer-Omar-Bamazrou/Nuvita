import 'package:cloud_firestore/cloud_firestore.dart';

class PatientSuggestionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Realtime stream of all suggestions for the patient, newest first
  Stream<List<Map<String, dynamic>>> listenToAllSuggestions(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('suggestions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // Count of unread suggestions — drives the bell badge on the home screen
  Stream<int> listenToUnreadCount(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('suggestions')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Marks a single suggestion document as read
  Future<void> markAsRead(String uid, String suggestionId) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('suggestions')
          .doc(suggestionId)
          .update({'read': true});
    } catch (e) {
      rethrow;
    }
  }

  // Human-friendly relative timestamp — no packages, manual calculation
  String timeAgo(Timestamp timestamp) {
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? "minute" : "minutes"} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? "hour" : "hours"} ago';
    }
    final d = diff.inDays;
    return '$d ${d == 1 ? "day" : "days"} ago';
  }
}
