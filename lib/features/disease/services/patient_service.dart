import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_model.dart';

class PatientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Saves profile as a map field on the existing /users/{uid} document
  Future<void> savePatientProfile(String uid, PatientModel model) async {
    await _firestore.collection('users').doc(uid).set(
      {
        'profile': {
          ...model.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }
}
