import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? getCurrentUser() => _auth.currentUser;

  Future<User?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  // Returns the generated Patient ID after creating the account
  Future<String> signUp(String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    final patientId = _generatePatientId();
    await _firestore.collection('users').doc(user.uid).set({
      'patientId': patientId,
      'name': name.trim(),
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'registered': true,
    });
    return patientId;
  }

  // Looks up the email linked to a Patient ID then signs in with it
  Future<User?> signInWithPatientId(String patientId, String password) async {
    final query = await _firestore
        .collection('users')
        .where('patientId', isEqualTo: patientId.toUpperCase().trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw FirebaseAuthException(code: 'patient-id-not-found');
    }
    final email = query.docs.first.data()['email'] as String;
    return signIn(email, password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String getErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-not-found':
        return 'No account found with this email';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'invalid-email':
        return 'Please enter a valid email';
      case 'patient-id-not-found':
        return 'No account found with this Patient ID';
      default:
        return 'Something went wrong. Please try again';
    }
  }

  String _generatePatientId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (i) => chars[random.nextInt(chars.length)]).join();
  }
}
