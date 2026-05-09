import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  Widget home;
  bool scheduleWellness = false;

  if (kIsWeb) {
    // Web build always lands on the doctor portal
    home = const DoctorLoginScreen();
  } else {
    // Mobile routing unchanged
    final onboardingDone = await PreferencesService.isOnboardingComplete();
    final user = FirebaseAuth.instance.currentUser;

    if (!onboardingDone) {
      home = const OnboardingScreen();
    } else if (user != null) {
      home = const MainShell();
      scheduleWellness = true;
    } else {
      home = const LoginScreen();
    }
  }

  await NotificationService.initialize(navigatorKey: navigatorKey);
  if (scheduleWellness) {
    await NotificationService.scheduleDailyWellnessReminder();
  }

  // Handles appointment notification taps — wired here to avoid circular
  // dependency between notification_service and appointment_service.
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

  runApp(NuvitaApp(home: home));
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
