import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../main.dart' show cancelDoctorNotificationListeners;
import '../../appointments/services/appointment_service.dart';
import '../../dashboard/providers/health_history_provider.dart';
import '../../emergency/screens/emergency_contacts_screen.dart';
import '../../emergency/trend_warning_service.dart';
import '../../medication/services/medication_service.dart';

// Ends a patient session so the next account on this device starts clean.
class AccountService {
  AccountService._();

  // Local keys that hold the signed-in user's data. The onboarding-complete
  // flag and device-level hints (e.g. the History swipe tip) are kept.
  static const _userDataKeys = {
    MedicationService.prefsKey,
    AppointmentService.prefsKey,
    EmergencyContactsScreen.prefsKey,
    TrendWarningService.prefsKey,
  };

  // Per-day "dose taken" flags: taken_{medId}_{time}_{yyyy-MM-dd}
  static const _takenFlagPrefix = 'taken_';

  // Sub-collections under /users/{uid}; all owned by the patient
  static const _userCollections = [
    'readings',
    'medications',
    'adherence',
    'appointments',
    'alerts',
    'messages',
    'suggestions',
    'emergency_contacts',
    'profile',
  ];

  // Deletes the signed-in patient's Firestore data and Firebase account,
  // then clears everything stored on the device so the app starts from
  // onboarding again. [password] re-authenticates first, which Firebase
  // requires before deleting an account. Throws FirebaseAuthException for a
  // wrong password; nothing is deleted in that case.
  static Future<void> deleteAccount({
    required String password,
    HealthHistoryProvider? history,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No signed-in email account');
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    for (final name in _userCollections) {
      await _deleteCollection(userDoc.collection(name));
    }
    await userDoc.delete();

    try {
      await user.delete();
    } finally {
      // Whatever happens to the auth account, the data is gone: leave the
      // device clean and signed out
      await clearLocalUserData(history: history);
      await PreferencesService.clearAll();
      await FirebaseAuth.instance.signOut();
    }
  }

  static Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> collection) async {
    while (true) {
      final snap = await collection.limit(400).get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static Future<void> signOut({HealthHistoryProvider? history}) async {
    await clearLocalUserData(history: history);
    await FirebaseAuth.instance.signOut();
  }

  // Cancels every scheduled notification, stops the doctor listeners, wipes
  // the user's local data and empties the in-memory readings.
  static Future<void> clearLocalUserData({HealthHistoryProvider? history}) async {
    await NotificationService.cancelAll();
    cancelDoctorNotificationListeners();

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (_userDataKeys.contains(key) || key.startsWith(_takenFlagPrefix)) {
        await prefs.remove(key);
      }
    }
    await PreferencesService.clearOnboardingDetails();

    history?.reset();
  }
}
