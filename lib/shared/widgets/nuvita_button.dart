import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class NuvitaButton extends StatelessWidget {
  const NuvitaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return _buildOutlined();
    }
    return _buildFilled();
  }

  Widget _buildFilled() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildChild(color: AppColors.white),
      ),
    );
  }

  Widget _buildOutlined() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.buttonText.copyWith(
            color: AppColors.primary,
          ),
        ),
        child: _buildChild(color: AppColors.primary),
      ),
    );
  }

  Widget _buildChild({required Color color}) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.buttonText.copyWith(color: color)),
        ],
      );
    }
    return Text(label, style: AppTextStyles.buttonText.copyWith(color: color));
  }
}