import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../../../core/services/preferences_service.dart';
import '../services/auth_service.dart';
import '../../home/screens/main_shell.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import 'register_screen.dart';
import 'forgot_password_sent_screen.dart';

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

      // Check if account was deactivated by a doctor
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (doc.data()?['active'] == false) {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showDeactivatedDialog();
            return;
          }
        } catch (_) {}
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

  void _showDeactivatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Account Deactivated'),
        content: const Text(
          'Your account has been deactivated by your doctor.\n\nPlease contact your healthcare provider for more information.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  Future<void> _showForgotPasswordDialog() async {
    final prefill = _emailController.text.trim().contains('@')
        ? _emailController.text.trim()
        : '';
    await showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        initialValue: prefill,
        authService: _authService,
        onSent: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ForgotPasswordSentScreen()),
          );
        },
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
                      onPressed: _showForgotPasswordDialog,
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

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialValue;
  final AuthService authService;
  final VoidCallback onSent;

  const _ForgotPasswordDialog({
    required this.initialValue,
    required this.authService,
    required this.onSent,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _controller;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Please enter your email or Patient ID');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      String email = input;
      if (!input.contains('@')) {
        email = await widget.authService.resolveEmailFromPatientId(input);
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      widget.onSent();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'user-not-found'
            ? 'No account found with this email'
            : 'Could not send reset email. Try again.';
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().contains('not-found')
            ? 'No account found with this Patient ID'
            : 'Could not send reset email. Try again.';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Forgot your password?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your email or Patient ID and we\'ll send you a reset link.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Email or Patient ID',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send Link'),
        ),
      ],
    );
  }
}

