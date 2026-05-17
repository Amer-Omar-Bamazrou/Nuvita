import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconly/iconly.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../services/auth_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../home/screens/main_shell.dart';
import '../../onboarding/screens/onboarding_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onRegisterPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final patientId = await _authService.signUp(
        _emailController.text,
        _passwordController.text,
        _nameController.text,
      );
      if (!mounted) return;
      await PreferencesService.setOnboardingComplete();

      // Sync onboarding profile data (gender, dob) to Firestore so the doctor dashboard can read them
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final firstName = await PreferencesService.getFirstName() ?? _nameController.text.trim().split(' ').first;
        final lastName  = await PreferencesService.getLastName()  ?? '';
        final gender    = await PreferencesService.getGender()    ?? '';
        final dob       = await PreferencesService.getDateOfBirth();
        await _authService.saveOnboardingProfile(
          uid: uid,
          firstName: firstName,
          lastName: lastName,
          gender: gender,
          dobIso: dob?.toIso8601String() ?? '',
        );
      }

      if (!mounted) return;
      await _showPatientIdDialog(patientId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _authService.getErrorMessage(e.code);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again';
        _isLoading = false;
      });
    }
  }

  Future<void> _showPatientIdDialog(String patientId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Account Created!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 52,
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Patient ID is:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 10),
            Text(
              patientId,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            const Text(
              'Share this with your doctor',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _goBackToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackToOnboarding();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _goBackToOnboarding,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Create Account', style: AppTextStyles.heading1),
                  const SizedBox(height: 8),
                  Text(
                    'Start your health journey with Nuvita',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  NuvitaTextField(
                    label: 'Full Name',
                    hint: 'John Doe',
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 20),
                  NuvitaTextField(
                    label: 'Email',
                    hint: 'your@email.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 20),
                  NuvitaTextField(
                    label: 'Password',
                    hint: 'At least 6 characters',
                    controller: _passwordController,
                    isPassword: true,
                    prefixIcon: IconlyLight.lock,
                    textInputAction: TextInputAction.next,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 20),
                  NuvitaTextField(
                    label: 'Confirm Password',
                    hint: 'Repeat your password',
                    controller: _confirmPasswordController,
                    isPassword: true,
                    prefixIcon: IconlyLight.lock,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 12),
                  _buildTermsNote(),
                  const SizedBox(height: 28),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.red.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  NuvitaButton(
                    label: 'Create Account',
                    onPressed: _onRegisterPressed,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  _buildLoginRow(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsNote() {
    return Text(
      'By creating an account, you agree to our Terms of Service and Privacy Policy.',
      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoginRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account?', style: AppTextStyles.bodySmall),
        TextButton(
          onPressed: _goBackToOnboarding,
          child: const Text('Sign In'),
        ),
      ],
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }
}
