import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../../shared/widgets/nuvita_text_field.dart';
import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      // Resolve email if user entered a Patient ID
      String email = _emailCtrl.text.trim();
      if (!email.contains('@')) {
        email = await _authService.resolveEmailFromPatientId(email);
      }

      // Re-authenticate then update password
      final cred = EmailAuthProvider.credential(
        email: email,
        password: _currentCtrl.text,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      await userCred.user!.updatePassword(_newCtrl.text);
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password updated. Please sign in.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Current password is incorrect'
            : e.code == 'user-not-found'
                ? 'No account found'
                : 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().contains('not-found')
            ? 'No account found with this Patient ID'
            : 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Set a new password', style: AppTextStyles.heading1),
            const SizedBox(height: 8),
            Text(
              'Enter your email and current password to confirm it\'s you.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 32),
            NuvitaTextField(
              label: 'Email or Patient ID',
              hint: 'your@email.com or ABC123',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 18),
            NuvitaTextField(
              label: 'Current Password',
              hint: 'Enter your current password',
              controller: _currentCtrl,
              isPassword: true,
              prefixIcon: Icons.lock_outline,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 18),
            NuvitaTextField(
              label: 'New Password',
              hint: 'At least 6 characters',
              controller: _newCtrl,
              isPassword: true,
              prefixIcon: Icons.lock_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 18),
            NuvitaTextField(
              label: 'Confirm New Password',
              hint: 'Repeat new password',
              controller: _confirmCtrl,
              isPassword: true,
              prefixIcon: Icons.lock_rounded,
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _newCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 28),
            if (_error != null) ...[
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            NuvitaButton(
              label: 'Save New Password',
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
