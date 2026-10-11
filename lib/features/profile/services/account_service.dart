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
