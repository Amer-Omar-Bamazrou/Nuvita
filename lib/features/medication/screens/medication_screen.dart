import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medication_rounded,
                size: 64,
                color: AppColors.divider,
              ),
              const SizedBox(height: 16),
              Text('Medications', style: AppTextStyles.heading2),
              const SizedBox(height: 8),
              Text('Coming soon', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
