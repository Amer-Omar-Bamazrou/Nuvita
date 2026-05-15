import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/preferences_service.dart';
import 'core/services/notification_service.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/main_shell.dart';
import 'features/dashboard/providers/health_history_provider.dart';
import 'features/doctor/screens/doctor_login_screen.dart';
import 'features/appointments/services/appointment_service.dart';
import 'features/appointments/screens/appointment_detail_screen.dart';
import 'features/medication/services/medication_service.dart';
import 'features/medication/screens/medication_detail_screen.dart';
import 'features/notifications/screens/suggestions_panel_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// Firestore listener subscriptions for doctor-assigned meds and suggestions
StreamSubscription<QuerySnapshot>? _medListenerSub;
StreamSubscription<QuerySnapshot>? _suggestionListenerSub;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  Widget home;
  bool scheduleWellness = false;
  String? loggedInUid;

  if (kIsWeb) {
    home = const DoctorLoginScreen();
  } else {
    final onboardingDone = await PreferencesService.isOnboardingComplete();
    final user = FirebaseAuth.instance.currentUser;

    if (!onboardingDone) {
      home = const OnboardingScreen();
    } else if (user != null) {
      bool deactivated = false;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.data()?['active'] == false) {
          await FirebaseAuth.instance.signOut();
          deactivated = true;
        }
      } catch (_) {}

      if (deactivated) {
        home = const LoginScreen();
      } else {
        home = const MainShell();
        scheduleWellness = true;
        loggedInUid = user.uid;
      }
    } else {
      home = const LoginScreen();
    }
  }

  await NotificationService.initialize(navigatorKey: navigatorKey);

  if (scheduleWellness) {
    try {
      await NotificationService.scheduleDailyWellnessReminder();
      await NotificationService.scheduleWeeklyHealthSummary();
    } catch (_) {}
  }

  // Appointment tap handler
  NotificationService.setAppointmentTapHandler((appointmentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final apt = await AppointmentService.getAppointmentById(appointmentId);
    if (apt == null) return;
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(
          appointment: apt,
          showConfirmDialog: true,
        ),
      ),
    );
  });

  // Medication detail tap handler (for missed dose / doctor assigned)
  NotificationService.setMedicationDetailHandler((medicationId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final med = await MedicationService.getById(medicationId);
    if (med == null) return;
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationDetailScreen(medication: med),
      ),
    );
  });

  // Suggestions panel tap handler (for doctor suggestion / weekly summary)
  NotificationService.setSuggestionsPanelHandler(() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SuggestionsPanelScreen(
          diseaseType: '',
          currentReadings: {},
        ),
      ),
    );
  });

  // Start Firestore listeners for logged-in patient
  if (loggedInUid != null) {
    _startDoctorNotificationListeners(loggedInUid);
  }

  runApp(NuvitaApp(home: home));
}

// Listens for doctor-assigned medications and doctor-sent suggestions.
// Shows a local notification when a new document is detected.
void _startDoctorNotificationListeners(String uid) {
  // Track known doc IDs to avoid notifying for existing documents on first load
  Set<String>? knownMedIds;
  Set<String>? knownSuggestionIds;

  // Doctor-assigned medications
  _medListenerSub?.cancel();
  _medListenerSub = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('medications')
      .snapshots()
      .listen((snapshot) {
    final currentIds = snapshot.docs.map((d) => d.id).toSet();

    if (knownMedIds == null) {
      // First snapshot — just record existing IDs
      knownMedIds = currentIds;
      return;
    }

    for (final doc in snapshot.docs) {
      if (knownMedIds!.contains(doc.id)) continue;
      final data = doc.data();
      if (data['addedByDoctor'] == true) {
        NotificationService.showDoctorAssignedMedNotification(
          medId: doc.id,
          doctorName: data['doctorName'] as String? ?? 'Your Doctor',
          medName: data['name'] as String? ?? 'Medication',
          dosage: data['dosage'] as String? ?? '',
        );
      }
    }
    knownMedIds = currentIds;
  });

  // Doctor-sent suggestions
  _suggestionListenerSub?.cancel();
  _suggestionListenerSub = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('suggestions')
      .snapshots()
      .listen((snapshot) {
    final currentIds = snapshot.docs.map((d) => d.id).toSet();

    if (knownSuggestionIds == null) {
      knownSuggestionIds = currentIds;
      return;
    }

    for (final doc in snapshot.docs) {
      if (knownSuggestionIds!.contains(doc.id)) continue;
      final data = doc.data();
      NotificationService.showDoctorSuggestionNotification(
        suggestionId: doc.id,
        doctorName: data['doctorName'] as String? ?? 'Your Doctor',
      );
    }
    knownSuggestionIds = currentIds;
  });
}

void cancelDoctorNotificationListeners() {
  _medListenerSub?.cancel();
  _suggestionListenerSub?.cancel();
  _medListenerSub = null;
  _suggestionListenerSub = null;
}

class NuvitaApp extends StatelessWidget {
  final Widget home;

  const NuvitaApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HealthHistoryProvider(),
      child: MaterialApp(
        title: 'Nuvita',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorKey: navigatorKey,
        home: home,
      ),
    );
  }
}
