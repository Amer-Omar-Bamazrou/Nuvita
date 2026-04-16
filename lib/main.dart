import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/preferences_service.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final onboardingDone = await PreferencesService.isOnboardingComplete();
  final user = FirebaseAuth.instance.currentUser;

  // Decide where to land based on onboarding state and auth state
  Widget home;
  if (!onboardingDone) {
    home = const OnboardingScreen();
  } else if (user != null) {
    home = const MainShell();
  } else {
    home = const LoginScreen();
  }

  runApp(NuvitaApp(home: home));
}

class NuvitaApp extends StatelessWidget {
  final Widget home;

  const NuvitaApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuvita',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    );
  }
}