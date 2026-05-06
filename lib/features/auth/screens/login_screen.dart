import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../services/auth_service.dart';
import '../../home/screens/main_shell.dart';
import '../../onboarding/screens/onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _patientIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(
        _emailController.text,
        _passwordController.text,
        _patientIdController.text.trim().toUpperCase(),
      );

      // Cache the first name locally so the home screen greeting is instant
      // before the Firestore profile load completes
      final firstName = _nameController.text.trim().split(' ').first;
      if (firstName.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('onboarding_first_name', firstName);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on PatientNotFoundException {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Patient ID not recognised. Please contact your doctor.';
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            (e.code == 'wrong-password' || e.code == 'invalid-credential')
                ? 'Incorrect password. Please try again.'
                : _authService.getErrorMessage(e.code);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _goBackToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _goBackToOnboarding();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  _buildLogo(),
                  const SizedBox(height: 40),
                  Text('Welcome back', style: AppTextStyles.heading1),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in with your Patient ID to continue',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 40),
                  NuvitaTextField(
                    label: 'Full Name',
                    hint: 'Your full name',
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Full name is required'
                        : null,
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
                    label: 'Patient ID',
                    hint: 'Enter your Patient ID',
                    controller: _patientIdController,
                    prefixIcon: Icons.badge_rounded,
                    textInputAction: TextInputAction.next,
                    // Force uppercase display as the user types
                    onChanged: (v) {
                      final upper = v.toUpperCase();
                      if (upper != v) {
                        _patientIdController.value =
                            _patientIdController.value.copyWith(
                          text: upper,
                          selection: TextSelection.collapsed(
                              offset: upper.length),
                        );
                      }
                    },
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Patient ID is required'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  NuvitaTextField(
                    label: 'Password',
                    hint: 'Enter your password',
                    controller: _passwordController,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    textInputAction: TextInputAction.done,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 32),
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
                    label: 'Sign In',
                    onPressed: _onLoginPressed,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: AppColors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Nuvita',
          style: AppTextStyles.heading2.copyWith(
            fontSize: 26,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}
