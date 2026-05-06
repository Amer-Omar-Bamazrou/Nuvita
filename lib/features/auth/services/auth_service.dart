import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Thrown when the entered Patient ID doesn't match the Firestore record
class PatientNotFoundException implements Exception {
  final String message;
  const PatientNotFoundException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? getCurrentUser() => _auth.currentUser;

  // Patient login flow:
  // 1. Firebase Auth signIn (handles email/password validation)
  // 2. Read the authenticated user's own Firestore document
  // 3. Compare stored patientId — sign out and reject if it doesn't match
  //
  // Note: we authenticate first because Firestore rules require auth to read
  // /users/{uid}. The patientId check is the second security gate.
  Future<User?> signIn(String email, String password, String patientId) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final storedId = doc.data()?['patientId'] as String?;

      if (storedId == null ||
          storedId.toUpperCase() != patientId.trim().toUpperCase()) {
        await _auth.signOut();
        throw const PatientNotFoundException(
          'Patient ID not found. Please register with your doctor to access Nuvita.',
        );
      }
    } catch (e) {
      if (e is PatientNotFoundException) rethrow;
      // Firestore failure — revoke session to avoid access with an unverified ID
      await _auth.signOut();
      throw const PatientNotFoundException(
        'Patient ID not found. Please register with your doctor to access Nuvita.',
      );
    }

    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Maps Firebase Auth error codes to user-friendly messages
  String getErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
