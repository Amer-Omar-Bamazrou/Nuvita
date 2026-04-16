import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nuvita_button.dart';
import '../../home/screens/main_shell.dart';

// ─── Disease option data ──────────────────────────────────────────────────────

class _DiseaseOption {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;

  const _DiseaseOption({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DiseaseSelectionScreen extends StatefulWidget {
  const DiseaseSelectionScreen({super.key});

  @override
  State<DiseaseSelectionScreen> createState() => _DiseaseSelectionScreenState();
}

class _DiseaseSelectionScreenState extends State<DiseaseSelectionScreen> {
  String? _selectedDisease;
  bool _isLoading = false;

  static const _diseases = [
    _DiseaseOption(
      id: 'diabetes',
      emoji: '🩸',
      title: 'Diabetes',
      subtitle: 'Type 1 & Type 2',
    ),
    _DiseaseOption(
      id: 'blood_pressure',
      emoji: '💉',
      title: 'Blood Pressure',
      subtitle: 'Hypertension',
    ),
    _DiseaseOption(
      id: 'heart',
      emoji: '❤️',
      title: 'Heart Condition',
      subtitle: 'Cardiovascular',
    ),
    _DiseaseOption(
      id: 'other',
      emoji: '➕',
      title: 'Other',
      subtitle: 'General monitoring',
    ),
  ];

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onContinue() async {
    if (_selectedDisease == null) {
      _showError('Please select your condition to continue');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Save only the disease type — personal info was collected in onboarding
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'profile': {
              'diseaseType': _selectedDisease,
              'createdAt': FieldValue.serverTimestamp(),
            },
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to save. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("What's your condition?", style: AppTextStyles.heading1),
              const SizedBox(height: 8),
              Text(
                'Select your chronic condition to personalise your experience',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 28),
              ..._diseases.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DiseaseCard(
                    emoji: d.emoji,
                    title: d.title,
                    subtitle: d.subtitle,
                    isSelected: _selectedDisease == d.id,
                    onTap: () => setState(() => _selectedDisease = d.id),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              NuvitaButton(
                label: 'Continue',
                onPressed: _selectedDisease != null ? _onContinue : null,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DiseaseCard ──────────────────────────────────────────────────────────────

class DiseaseCard extends StatelessWidget {
  const DiseaseCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.07)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
