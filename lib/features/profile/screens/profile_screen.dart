import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../auth/screens/login_screen.dart';
import '../../report/screens/report_screen.dart';
import '../../appointments/screens/appointments_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isGuest = false;
  String _name = '';
  String _diseaseType = 'other';
  String _patientId = '';
  bool _signingOut = false;

  static const _diseaseLabels = {
    'diabetes': 'Diabetes',
    'blood_pressure': 'Blood Pressure',
    'heart': 'Heart Condition',
    'other': 'General Monitoring',
  };

  static const _diseaseEmojis = {
    'diabetes': '🩸',
    'blood_pressure': '💉',
    'heart': '❤️',
    'other': '➕',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isGuest = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data() ?? {};

      // Doctor-created accounts store fields flat at root level.
      // Old self-registered accounts stored them inside a nested 'profile' map.
      // Try root first, fall back to nested map.
      final profile = data['profile'] as Map<String, dynamic>?;
      final name = data['name'] as String? ?? profile?['name'] as String? ?? '';
      final disease = data['diseaseType'] as String? ??
          profile?['diseaseType'] as String? ??
          'other';
      final patientId = data['patientId'] as String? ?? '';

      setState(() {
        _name = name;
        _diseaseType = disease;
        _patientId = patientId;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
    }
  }

  void _copyPatientId() {
    if (_patientId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _patientId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Patient ID copied to clipboard'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            bool isLoading = false;
            String? errorMsg;

            Future<void> submit() async {
              final current = currentPasswordController.text;
              final next = newPasswordController.text;
              final confirm = confirmPasswordController.text;

              if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                setSheetState(() => errorMsg = 'All fields are required.');
                return;
              }
              if (next.length < 6) {
                setSheetState(
                    () => errorMsg = 'New password must be at least 6 characters.');
                return;
              }
              if (next != confirm) {
                setSheetState(() => errorMsg = 'Passwords do not match.');
                return;
              }

              setSheetState(() {
                isLoading = true;
                errorMsg = null;
              });

              try {
                final user = FirebaseAuth.instance.currentUser!;
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: current,
                );
                // Capture before the first await to avoid cross-async-gap context use
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(next);

                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Password updated successfully'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                setSheetState(() {
                  isLoading = false;
                  errorMsg = e.code == 'wrong-password' ||
                          e.code == 'invalid-credential'
                      ? 'Current password is incorrect.'
                      : 'Something went wrong. Please try again.';
                });
              } catch (_) {
                setSheetState(() {
                  isLoading = false;
                  errorMsg = 'Something went wrong. Please try again.';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Change Password', style: AppTextStyles.heading2),
                  const SizedBox(height: 20),
                  _sheetTextField(
                    controller: currentPasswordController,
                    label: 'Current Password',
                    isPassword: true,
                  ),
                  const SizedBox(height: 14),
                  _sheetTextField(
                    controller: newPasswordController,
                    label: 'New Password',
                    isPassword: true,
                  ),
                  const SizedBox(height: 14),
                  _sheetTextField(
                    controller: confirmPasswordController,
                    label: 'Confirm New Password',
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.red.shade700),
                    ),
                  ],
                  const SizedBox(height: 24),
                  NuvitaButton(
                    label: 'Update Password',
                    onPressed: isLoading ? null : submit,
                    isLoading: isLoading,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetTextField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.label,
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return _isGuest ? _buildGuestView() : _buildProfileView();
  }

  // Shown when the user skipped sign-in during onboarding
  Widget _buildGuestView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text('Sign in to sync your data', style: AppTextStyles.heading1),
              const SizedBox(height: 10),
              Text(
                'Sign in with your Patient ID to save your health data to the cloud and access it from any device.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              NuvitaButton(
                label: 'Sign In',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Shown for authenticated users
  Widget _buildProfileView() {
    final initials = _initials(_name.isEmpty ? '?' : _name);
    final label = _diseaseLabels[_diseaseType] ?? 'General Monitoring';
    final emoji = _diseaseEmojis[_diseaseType] ?? '➕';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Avatar and name section
              Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 24),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _name.isEmpty ? 'Unknown' : _name,
                      style: AppTextStyles.heading1,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppColors.divider, width: 1.5),
                      ),
                      child: Text(
                        '$emoji  $label',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient ID card
                    if (_patientId.isNotEmpty) ...[
                      Text(
                        'Patient ID',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _patientId,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Provided by your doctor',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy_rounded,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                              onPressed: _copyPatientId,
                              tooltip: 'Copy Patient ID',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Change password card
                    Text(
                      'Security',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showChangePasswordSheet,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Change Password',
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Update your account password',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Health Report card
                    Text(
                      'Health Report',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ReportScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.description_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Generate & Share Report',
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Create a PDF of your last 30 days and share with your doctor',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Appointments card
                    Text(
                      'My Appointments',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AppointmentsScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Appointments',
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Manage your doctor appointments and get reminders',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    NuvitaButton(
                      label: 'Sign Out',
                      onPressed: _signingOut ? null : _signOut,
                      isLoading: _signingOut,
                      isOutlined: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
