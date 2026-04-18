import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/lifestyle_suggestion.dart';

class SuggestionCard extends StatelessWidget {
  final LifestyleSuggestion suggestion;

  const SuggestionCard({super.key, required this.suggestion});

  Color get _priorityColor {
    switch (suggestion.priority) {
      case SuggestionPriority.high:
        return AppColors.error;
      case SuggestionPriority.medium:
        return AppColors.warning;
      case SuggestionPriority.low:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coloured left strip indicating priority level
          Container(
            width: 5,
            height: double.infinity,
            constraints: const BoxConstraints(minHeight: 72),
            decoration: BoxDecoration(
              color: _priorityColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(suggestion.icon, color: _priorityColor, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.title,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textDark,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          suggestion.description,
                          style: AppTextStyles.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
