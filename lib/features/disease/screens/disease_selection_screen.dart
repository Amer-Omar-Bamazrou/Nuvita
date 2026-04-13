import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// Placeholder — full UI (condition cards, multi-select, etc.) comes next
class DiseaseSelectionScreen extends StatelessWidget {
  const DiseaseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Text(
            'Select Your Condition',
            style: AppTextStyles.heading1,
          ),
        ),
      ),
    );
  }
}
