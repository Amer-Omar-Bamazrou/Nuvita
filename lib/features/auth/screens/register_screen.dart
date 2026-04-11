import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';

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
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // TODO: hook up Firebase Auth here
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // TODO: go to disease selection after signup
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
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
                const SizedBox(height: 36),
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
                  prefixIcon: Icons.lock_outline,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 20),
                NuvitaTextField(
                  label: 'Confirm Password',
                  hint: 'Repeat your password',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 12),
                _buildTermsNote(),
                const SizedBox(height: 32),
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
          onPressed: () => Navigator.of(context).pop(),
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