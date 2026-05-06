import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../../../core/services/preferences_service.dart';
import '../services/auth_service.dart';
import '../../home/screens/main_shell.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
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
      final input = _emailController.text.trim();
      // If no @ symbol and exactly 6 alphanumeric chars, treat as Patient ID
      final isPatientId =
          !input.contains('@') && RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(input);

      if (isPatientId) {
        await _authService.signInWithPatientId(input, _passwordController.text);
      } else {
        await _authService.signIn(input, _passwordController.text);
      }

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

  Future<void> _navigateToRegister() async {
    final onboardingDone = await PreferencesService.isOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            onboardingDone ? const RegisterScreen() : const OnboardingScreen(),
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
    return WillPopScope(
      onWillPop: () async {
        _goBackToOnboarding();
        return false;
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                    'Sign in to continue tracking your health',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 40),
                  NuvitaTextField(
                    label: 'Email or Patient ID',
                    hint: 'your@email.com or ABC123',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmailOrId,
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
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: forgot password flow
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),
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
                    label: 'Sign In',
                    onPressed: _onLoginPressed,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('New user?', style: AppTextStyles.bodySmall),
                      TextButton(
                        onPressed: _navigateToRegister,
                        child: const Text('Create Account'),
                      ),
                    ],
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

  String? _validateEmailOrId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or Patient ID is required';
    }
    final input = value.trim();
    // Accept valid email
    if (input.contains('@')) {
      final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(input)) {
        return 'Enter a valid email address';
      }
      return null;
    }
    // Accept 6-character alphanumeric Patient ID
    if (RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(input)) return null;
    return 'Enter your email or 6-character Patient ID';
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
}
