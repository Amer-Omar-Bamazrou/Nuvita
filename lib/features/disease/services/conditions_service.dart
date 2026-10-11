import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/health/conditions.dart';

// Reads and writes the patient's conditions on /users/{uid}.profile
class ConditionsService {
  ConditionsService._();

  // Bumped after a save so open screens (Home, Charts) can reload
  static final changes = ValueNotifier<int>(0);

  static DocumentReference<Map<String, dynamic>> _user(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  static Future<PatientConditions> load(String uid) async {
    final doc = await _user(uid).get();
    return PatientConditions.fromProfile(
        doc.data()?['profile'] as Map<String, dynamic>?);
  }

  static Future<void> save(String uid, PatientConditions conditions) async {
    await _user(uid).set({
      'profile': conditions.toProfileFields(),
    }, SetOptions(merge: true));
    changes.value++;
  }
}
