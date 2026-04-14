import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _name = '';
  String _diseaseType = 'other';
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
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final profile = doc.data()?['profile'] as Map<String, dynamic>?;
      setState(() {
        _name = profile?['name'] as String? ?? '';
        _diseaseType = profile?['diseaseType'] as String? ?? 'other';
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
      // Remove entire stack — landing on LoginScreen starts fresh
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
    }
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

    final initials = _initials(_name.isEmpty ? '?' : _name);
    final label = _diseaseLabels[_diseaseType] ?? 'General Monitoring';
    final emoji = _diseaseEmojis[_diseaseType] ?? '➕';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Profile info — centered in the available space
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large initials avatar
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
                    // Disease badge
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
            ),
            // Sign out at the bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: NuvitaButton(
                label: 'Sign Out',
                onPressed: _signingOut ? null : _signOut,
                isLoading: _signingOut,
                isOutlined: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
